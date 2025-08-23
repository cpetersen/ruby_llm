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
        def complete(messages, tools: [], temperature: nil, model: nil, stream: false, schema: nil, connection: nil, params: {}, &block)
          model_id = resolve_model(model)
          
          # Load the model (cached after first load)
          llm = load_model(model_id)
          
          # Build config with the loaded model for schema constraints
          config = build_generation_config(temperature, schema, llm)
          
          # If a block is given, assume streaming
          if block_given?
            complete_streaming(llm, messages, config, &block)
          else
            complete_sync(llm, messages, config)
          end
        end

        module_function

        private

        def complete_sync(llm, messages, config)
          # Convert messages to format expected by red-candle
          formatted_messages = format_messages_for_chat(messages)
          
          # Use red-candle's chat method
          if formatted_messages.is_a?(Array) && formatted_messages.any? { |m| m.is_a?(Hash) && m["role"] }
            response_text = llm.chat(formatted_messages, config: config)
          else
            # Fall back to generate for simple prompts
            prompt = messages.is_a?(Array) ? messages.map(&:content).join("\n") : messages.to_s
            response_text = llm.generate(prompt, config: config)
          end
          
          # Parse the response into a Message object
          parse_completion_response(response_text, llm)
        end

        def complete_streaming(llm, messages, config, &block)
          # Convert messages to format expected by red-candle
          formatted_messages = format_messages_for_chat(messages)
          accumulated_text = ""
          
          # Use red-candle's chat_stream method
          if formatted_messages.is_a?(Array) && formatted_messages.any? { |m| m.is_a?(Hash) && m["role"] }
            llm.chat_stream(formatted_messages, config: config) do |token|
              accumulated_text += token
              chunk = build_chunk(token, accumulated_text, llm.model_name)
              block.call(chunk) if block
            end
          else
            # Fall back to generate_stream for simple prompts
            prompt = messages.is_a?(Array) ? messages.map(&:content).join("\n") : messages.to_s
            llm.generate_stream(prompt, config: config) do |token|
              accumulated_text += token
              chunk = build_chunk(token, accumulated_text, llm.model_name)
              block.call(chunk) if block
            end
          end
          
          # Return the final message
          parse_completion_response(accumulated_text, llm)
        end

        def format_messages_for_chat(messages)
          # Convert messages to the format expected by red-candle's chat method
          if messages.is_a?(Array)
            messages.map do |msg|
              if msg.respond_to?(:to_h)
                hash = msg.to_h
                # Convert symbol keys to string keys for red-candle
                {
                  "role" => hash[:role].to_s,
                  "content" => hash[:content].to_s
                }
              elsif msg.is_a?(Hash)
                # Ensure string keys
                {
                  "role" => (msg["role"] || msg[:role]).to_s,
                  "content" => (msg["content"] || msg[:content]).to_s
                }
              else
                msg
              end
            end
          else
            messages
          end
        end
        

        def parse_completion_response(text, llm)
          Message.new(
            content: text,
            role: :assistant,
            model_id: llm.model_name
          )
        end

        def resolve_model(model)
          RedCandle.resolve_model(model)
        end

        def build_generation_config(temperature, schema, llm = nil)
          RedCandle.ensure_red_candle_available!
          
          # Build config options
          config_options = {}
          config_options[:temperature] = temperature if temperature
          
          # Add structured generation constraint if schema provided
          if schema && llm
            constraint = llm.constraint_from_schema(schema)
            config_options[:constraint] = constraint
          end
          
          # Create config with all options
          if config_options.any?
            ::Candle::GenerationConfig.new(**config_options)
          else
            ::Candle::GenerationConfig.balanced
          end
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