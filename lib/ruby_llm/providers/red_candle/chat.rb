# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Chat completion implementation for RedCandle provider.
      # Handles model loading, message formatting, and response generation.
      module Chat
        module_function

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
          # Use the provided model or fall back to configuration default
          model || RubyLLM.configuration.red_candle_default_model || "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
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
            constraint = load_model(nil).constraint_from_schema(schema)
            base_config.constraint = constraint
          end
          
          base_config
        end

        def load_model(model_id)
          RedCandle.ensure_red_candle_available!
          # This would be enhanced with caching in a real implementation
          device = get_device
          ::Candle::LLM.from_pretrained(model_id, device: device)
        end

        def get_device
          RedCandle.ensure_red_candle_available!
          device_type = RubyLLM.configuration.red_candle_device || 'cpu'
          case device_type.to_s.downcase
          when 'metal'
            ::Candle::Device.metal
          when 'cuda'
            ::Candle::Device.cuda
          else
            ::Candle::Device.cpu
          end
        end
      end
    end
  end
end