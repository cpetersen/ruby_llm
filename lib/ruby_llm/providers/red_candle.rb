# frozen_string_literal: true

require_relative 'red_candle/capabilities'
require_relative 'red_candle/chat'
require_relative 'red_candle/models'
require_relative 'red_candle/streaming'
require_relative 'red_candle/structured_generation'

module RubyLLM
  module Providers
    # RedCandle provider for local LLM inference using the red-candle gem.
    # Supports CPU, Metal (Apple Silicon), and CUDA acceleration.
    # Provides native Ruby LLM capabilities without external API dependencies.
    module RedCandle
      extend Provider
      extend RedCandle::Chat
      extend RedCandle::Streaming
      extend RedCandle::Models
      extend RedCandle::StructuredGeneration

      module_function

      def api_base(_config)
        # Not applicable for local provider
        nil
      end

      def headers(_config)
        # No authentication needed for local provider
        {}
      end

      def capabilities
        RedCandle::Capabilities
      end

      def slug
        'red_candle'
      end

      def configuration_requirements
        # Device is optional, defaults to CPU
        []
      end

      def local?
        true
      end

      def ensure_red_candle_available!
        return if defined?(::Candle)
        
        raise ConfigurationError, <<~ERROR
          The red-candle gem is not installed. To use the RedCandle provider, please add it to your Gemfile:
          
            gem 'red-candle'
          
          Then run:
          
            bundle install
          
          For more information, visit: https://github.com/your-org/red-candle
        ERROR
      end

      def resolve_model(model)
        # Use the provided model or fall back to configuration default
        model || RubyLLM.configuration.red_candle_default_model || "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
      end

      def load_model(model_id)
        ensure_red_candle_available!
        # This would be enhanced with caching in a real implementation
        device = get_device
        ::Candle::LLM.from_pretrained(model_id, device: device)
      end

      def get_device
        ensure_red_candle_available!
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