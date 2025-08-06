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
          
          # For now, manually format the prompt since apply_chat_template seems broken
          # for TinyLlama in red-candle
          if formatted_messages.is_a?(Array) && formatted_messages.any? { |m| m.is_a?(Hash) && m["role"] }
            prompt = format_as_tinyllama_chat(formatted_messages)
            response_text = llm.generate(prompt, config: config)
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
          
          # For now, manually format the prompt since apply_chat_template seems broken
          if formatted_messages.is_a?(Array) && formatted_messages.any? { |m| m.is_a?(Hash) && m["role"] }
            prompt = format_as_tinyllama_chat(formatted_messages)
            llm.generate_stream(prompt, config: config) do |token|
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

        def format_as_tinyllama_chat(messages)
          # Manually format messages for TinyLlama chat template
          # Format: <|system|>\n{system}\n<|user|>\n{user}\n<|assistant|>\n{assistant}\n...
          formatted = ""
          
          messages.each do |msg|
            role = msg["role"] || msg[:role]
            content = msg["content"] || msg[:content]
            
            case role.to_s
            when "system"
              formatted += "<|system|>\n#{content}\n"
            when "user"
              formatted += "<|user|>\n#{content}\n"
            when "assistant"
              formatted += "<|assistant|>\n#{content}\n"
            end
          end
          
          # Always end with assistant tag for generation
          formatted += "<|assistant|>\n" unless formatted.end_with?("<|assistant|>\n")
          
          formatted
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
        
        def format_messages_for_model(llm, messages)
          # This method is kept for backward compatibility but not actively used
          # The complete_sync and complete_streaming methods now use format_messages_for_chat
          # and call llm.chat directly
          if messages.is_a?(Array)
            formatted_messages = messages.map do |msg|
              if msg.respond_to?(:to_h)
                hash = msg.to_h
                {
                  "role" => hash[:role].to_s,
                  "content" => hash[:content].to_s
                }
              else
                msg
              end
            end
            
            if formatted_messages.any? { |m| m.is_a?(Hash) && (m["role"] || m[:role]) }
              llm.apply_chat_template(formatted_messages)
            else
              formatted_messages.join("\n")
            end
          else
            messages.to_s
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