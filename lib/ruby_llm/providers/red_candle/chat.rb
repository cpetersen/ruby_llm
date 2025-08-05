# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Chat completion implementation for RedCandle provider.
      # Handles model loading, message formatting, and response generation.
      module Chat
        # Since we're a local provider, we don't use HTTP endpoints
        def completion_url
          raise NotImplementedError, "RedCandle is a local provider and doesn't use HTTP endpoints"
        end

        # Override the complete method to use red-candle directly
        def complete(messages, tools: [], temperature: nil, model: nil, stream: false, schema: nil, connection: nil, params: {}, &)
          model_id = resolve_model(model)
          config = build_generation_config(temperature, schema)
          
          # Load the model (cached after first load)
          llm = load_model(model_id)
          
          if stream
            complete_streaming(llm, messages, config, &)
          else
            complete_sync(llm, messages, config)
          end
        end

        module_function

        private

        def complete_sync(llm, messages, config)
          prompt = format_messages_for_model(llm, messages)
          response_text = llm.generate(prompt, config: config)
          
          # Parse the response into a Message object
          parse_completion_response(response_text, llm)
        end

        def complete_streaming(llm, messages, config, &block)
          prompt = format_messages_for_model(llm, messages)
          accumulated_text = ""
          
          llm.generate_stream(prompt, config: config) do |token|
            accumulated_text += token
            chunk = build_chunk(token, accumulated_text)
            block.call(chunk) if block
          end
          
          # Return the final message
          parse_completion_response(accumulated_text, llm)
        end

        def format_messages_for_model(llm, messages)
          # Convert messages to the format expected by red-candle
          if messages.is_a?(Array) && messages.any? { |m| m[:role] }
            # Chat format - use chat template
            llm.apply_chat_template(messages)
          else
            # Single message or string
            messages.to_s
          end
        end

        def parse_completion_response(text, llm)
          Message.new(
            content: text,
            role: :assistant,
            model: llm.model_name
          )
        end

        def resolve_model(model)
          RedCandle.resolve_model(model)
        end

        def build_generation_config(temperature, schema)
          RedCandle.ensure_red_candle_available!
          base_config = if temperature
            ::Candle::GenerationConfig.new(temperature: temperature)
          else
            ::Candle::GenerationConfig.balanced
          end
          
          # Add structured generation constraint if schema provided
          if schema
            constraint = RedCandle.load_model(nil).constraint_from_schema(schema)
            base_config.constraint = constraint
          end
          
          base_config
        end

        def load_model(model_id)
          RedCandle.load_model(model_id)
        end

        def get_device
          RedCandle.get_device
        end
      end
    end
  end
end