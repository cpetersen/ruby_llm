# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Structured generation support for RedCandle provider.
      # Leverages red-candle's JSON schema and regex constraints.
      module StructuredGeneration
        module_function

        def supports_structured_output?(model_id)
          # All red-candle models support structured generation
          true
        end

        def generate_structured(prompt, schema:, model: nil, temperature: nil)
          RedCandle.ensure_red_candle_available!
          model_id = resolve_model(model)
          llm = load_model(model_id)
          
          # Use red-candle's built-in structured generation
          result = llm.generate_structured(prompt, schema: schema)
          
          # Wrap in a Message object with JSON string content
          Message.new(
            content: result.is_a?(Hash) ? result.to_json : result,
            role: :assistant,
            model: llm.model_name
          )
        end

        def generate_regex(prompt, pattern:, model: nil, temperature: nil)
          RedCandle.ensure_red_candle_available!
          model_id = resolve_model(model)
          llm = load_model(model_id)
          
          # Use red-candle's regex generation
          result = llm.generate_regex(prompt, pattern: pattern)
          
          Message.new(
            content: result,
            role: :assistant,
            model: llm.model_name
          )
        end

        # Convert ruby_llm schema format to red-candle format if needed
        def normalize_schema(schema)
          # Red-candle expects standard JSON schema format
          # Ruby_llm might have some variations we need to handle
          schema
        end
      end
    end
  end
end