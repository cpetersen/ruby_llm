# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Model management for RedCandle provider.
      # Lists available models from HuggingFace cache and common models.
      module Models
        SUPPORTED_MODELS = [
          # Mistral models
          "mistralai/Mistral-7B-Instruct-v0.1",
          "mistralai/Mistral-7B-Instruct-v0.2",
          "mistralai/Mistral-7B-Instruct-v0.3",
          
          # Llama models
          "meta-llama/Llama-2-7b-hf",
          "meta-llama/Llama-2-7b-chat-hf",
          "meta-llama/Llama-2-13b-hf",
          "meta-llama/Llama-2-13b-chat-hf",
          "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
          
          # Gemma models
          "google/gemma-2b",
          "google/gemma-2b-it",
          "google/gemma-7b",
          "google/gemma-7b-it",
          
          # Qwen models
          "Qwen/Qwen2-1.5B",
          "Qwen/Qwen2-1.5B-Instruct",
          "Qwen/Qwen2-7B",
          "Qwen/Qwen2-7B-Instruct",
          "Qwen/Qwen2.5-7B-Instruct",
          
          # Phi models
          "microsoft/phi-2",
          "microsoft/Phi-3-mini-4k-instruct",
          "microsoft/phi-4"
        ].freeze

        GGUF_MODEL_PATTERNS = [
          "TheBloke/*-GGUF",
          "QuantFactory/*-GGUF",
          "bartowski/*-GGUF"
        ].freeze

        def models_url
          raise NotImplementedError, "RedCandle doesn't use HTTP endpoints"
        end

        def list_models
          # Return a combination of known models and locally cached models
          models = SUPPORTED_MODELS.map do |model_id|
            Model::Info.new(
              id: model_id,
              name: model_id.split('/').last,
              provider: 'red_candle',
              modalities: { input: ['text'], output: ['text'] },
              capabilities: model_capabilities(model_id)
            )
          end
          
          # Add GGUF models note
          models << Model::Info.new(
            id: "gguf-models",
            name: "GGUF Quantized Models",
            provider: 'red_candle',
            modalities: { input: ['text'], output: ['text'] },
            capabilities: ['chat', 'completion'],
            metadata: { description: "Supports any GGUF quantized model from HuggingFace" }
          )
          
          models
        end

        private

        def model_capabilities(model_id)
          caps = ['completion']
          
          # Add chat capability for instruction-tuned models
          if model_id.downcase.include?('chat') || model_id.downcase.include?('instruct') || model_id.include?('-it')
            caps << 'chat'
          end
          
          # All models support structured generation
          caps << 'structured_output'
          
          caps
        end
      end
    end
  end
end