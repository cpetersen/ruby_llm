# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Model capabilities and metadata for RedCandle provider.
      module Capabilities
        module_function

        def context_window_for(model_id)
          case model_id
          when /mistral/i
            if model_id.include?('v0.3')
              32_768
            else
              8_192
            end
          when /llama.*2/i
            4_096
          when /llama.*3/i
            8_192
          when /tinyllama/i
            2_048
          when /gemma.*2b/i
            8_192
          when /gemma.*7b/i
            8_192
          when /qwen2\.5/i
            32_768
          when /qwen2.*7b/i
            32_768
          when /qwen2.*1\.5b/i
            32_768
          when /phi-2/i
            2_048
          when /phi-3/i
            4_096
          when /phi-4/i
            16_384
          else
            4_096 # Conservative default
          end
        end

        def max_tokens_for(model_id)
          # Red-candle doesn't have hard limits, but we'll provide reasonable defaults
          case model_id
          when /tinyllama/i
            1_024
          when /1\.5b|2b/i
            2_048
          else
            4_096
          end
        end

        def supports_vision?(_model_id)
          # Red-candle doesn't currently support vision models
          false
        end

        def supports_functions?(_model_id)
          # All models support function calling via structured generation
          true
        end

        def supports_structured_output?(_model_id)
          # All red-candle models support structured output via outlines crate
          true
        end
        
        def structured_output?(_model_id)
          # Alternative method name used by ruby_llm
          true
        end

        def supports_streaming?(_model_id)
          # All models support streaming
          true
        end

        def model_family(model_id)
          case model_id.downcase
          when /mistral/
            'mistral'
          when /llama/
            'llama'
          when /gemma/
            'gemma'
          when /qwen/
            'qwen'
          when /phi/
            'phi'
          else
            'unknown'
          end
        end

        def quantization_info(model_id)
          return nil unless model_id.include?('GGUF')
          
          # Extract quantization level from GGUF filename
          case model_id
          when /Q8_0/i
            { level: 'Q8_0', bits: 8, quality: 'highest' }
          when /Q5_K_M/i
            { level: 'Q5_K_M', bits: 5, quality: 'very_good' }
          when /Q4_K_M/i
            { level: 'Q4_K_M', bits: 4, quality: 'recommended' }
          when /Q3_K_M/i
            { level: 'Q3_K_M', bits: 3, quality: 'good' }
          when /Q2_K/i
            { level: 'Q2_K', bits: 2, quality: 'acceptable' }
          else
            { level: 'unknown', bits: nil, quality: 'unknown' }
          end
        end

        def hardware_requirements(model_id)
          # Rough estimates for memory requirements
          model_size = case model_id.downcase
          when /1\.1b|1\.5b/
            'small'
          when /2b/
            'small'
          when /7b/
            'medium'
          when /13b/
            'large'
          else
            'unknown'
          end

          case model_size
          when 'small'
            { min_ram: '4GB', recommended_ram: '8GB', gpu_recommended: false }
          when 'medium'
            { min_ram: '8GB', recommended_ram: '16GB', gpu_recommended: true }
          when 'large'
            { min_ram: '16GB', recommended_ram: '32GB', gpu_recommended: true }
          else
            { min_ram: 'unknown', recommended_ram: 'unknown', gpu_recommended: nil }
          end
        end
      end
    end
  end
end