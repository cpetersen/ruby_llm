# frozen_string_literal: true

module RubyLLM
  module Providers
    module RedCandle
      # Streaming support for RedCandle provider.
      # Converts red-candle's native streaming to ruby_llm's chunk format.
      module Streaming
        def stream_url
          raise NotImplementedError, "RedCandle is a local provider and doesn't use HTTP endpoints"
        end

        def build_chunk(token, accumulated_text = nil)
          # Convert red-candle token to ruby_llm Chunk format
          Chunk.new(
            content: token,
            role: 'assistant',
            finish_reason: nil,
            model: current_model_name,
            tool_calls: []
          )
        end

        def parse_streaming_error(data)
          # Red-candle errors are raised as exceptions, not streaming data
          nil
        end

        private

        def current_model_name
          # This would be set during model loading
          @current_model_name || "red-candle"
        end
      end
    end
  end
end