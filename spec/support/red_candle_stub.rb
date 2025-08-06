# frozen_string_literal: true

# Stub for red-candle gem to allow unit tests to run without the actual gem
# This is only loaded when the real Candle module is not available

module Candle
  class Device
    def self.cpu
      new(:cpu)
    end

    def self.metal
      new(:metal)
    end

    def self.cuda
      new(:cuda)
    end

    def initialize(type)
      @type = type
    end
  end

  class GenerationConfig
    attr_accessor :temperature, :max_length

    def self.balanced
      new
    end

    def self.deterministic
      new
    end

    def self.creative
      new
    end

    def initialize(options = {})
      @temperature = options[:temperature] || 0.7
      @max_length = options[:max_length] || 512
    end
  end

  class LLM
    def self.from_pretrained(model_id, device: nil)
      new(model_id)
    end

    def initialize(model_id)
      @model_name = model_id
    end

    attr_reader :model_name

    def generate(prompt, config: nil)
      "Generated response for: #{prompt}"
    end

    def generate_stream(prompt, config: nil, &block)
      tokens = ["Generated", " response", " for:", " #{prompt}"]
      tokens.each { |token| block.call(token) if block }
      tokens.join
    end

    def chat(messages, config: nil)
      "Chat response"
    end

    def chat_stream(messages, config: nil, &block)
      tokens = ["Chat", " response"]
      tokens.each { |token| block.call(token) if block }
      tokens.join
    end

    def apply_chat_template(messages)
      # Mimics the broken behavior we found
      ""
    end

    def constraint_from_schema(schema)
      { type: :schema, schema: schema }
    end

    def constraint_from_regex(pattern)
      { type: :regex, pattern: pattern }
    end

    def generate_structured(prompt, schema:)
      { "answer" => "yes" }
    end

    def clear_cache
      # No-op
    end
  end
end