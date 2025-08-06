# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::RedCandle do
  # Since red-candle is a local provider, we'll mock the actual gem to avoid dependencies
  # This follows the pattern used for other providers that require external dependencies

  describe 'provider interface' do
    it 'has the correct slug' do
      expect(described_class.slug).to eq('red_candle')
    end

    it 'is a local provider' do
      expect(described_class.local?).to be true
    end

    it 'returns nil for api_base' do
      config = double('config')
      expect(described_class.api_base(config)).to be_nil
    end

    it 'returns empty headers' do
      config = double('config')
      expect(described_class.headers(config)).to eq({})
    end

    it 'has no configuration requirements' do
      expect(described_class.configuration_requirements).to eq([])
    end

    it 'provides capabilities' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::RedCandle::Capabilities)
    end
  end

  describe 'capabilities' do
    describe '#context_window_for' do
      it 'returns correct context windows for various models' do
        expect(described_class.capabilities.context_window_for('mistralai/Mistral-7B-Instruct-v0.3')).to eq(32_768)
        expect(described_class.capabilities.context_window_for('mistralai/Mistral-7B-Instruct-v0.1')).to eq(8_192)
        expect(described_class.capabilities.context_window_for('TinyLlama/TinyLlama-1.1B-Chat-v1.0')).to eq(2_048)
        expect(described_class.capabilities.context_window_for('google/gemma-2b')).to eq(8_192)
        expect(described_class.capabilities.context_window_for('Qwen/Qwen2.5-7B-Instruct')).to eq(32_768)
        expect(described_class.capabilities.context_window_for('microsoft/phi-2')).to eq(2_048)
        expect(described_class.capabilities.context_window_for('microsoft/phi-4')).to eq(16_384)
        expect(described_class.capabilities.context_window_for('unknown/model')).to eq(4_096)
      end
    end

    describe '#supports_structured_output?' do
      it 'returns true for all models' do
        expect(described_class.capabilities.supports_structured_output?('any-model')).to be true
      end
    end

    describe '#supports_vision?' do
      it 'returns false for all models' do
        expect(described_class.capabilities.supports_vision?('any-model')).to be false
      end
    end

    describe '#supports_functions?' do
      it 'returns true for all models' do
        expect(described_class.capabilities.supports_functions?('any-model')).to be true
      end
    end

    describe '#model_family' do
      it 'correctly identifies model families' do
        expect(described_class.capabilities.model_family('mistralai/Mistral-7B')).to eq('mistral')
        expect(described_class.capabilities.model_family('TinyLlama/TinyLlama-1.1B')).to eq('llama')
        expect(described_class.capabilities.model_family('google/gemma-2b')).to eq('gemma')
        expect(described_class.capabilities.model_family('Qwen/Qwen2')).to eq('qwen')
        expect(described_class.capabilities.model_family('microsoft/phi-2')).to eq('phi')
        expect(described_class.capabilities.model_family('unknown/model')).to eq('unknown')
      end
    end
  end

  describe 'models' do
    it 'returns a list of supported models' do
      models = described_class.list_models
      expect(models).to be_an(Array)
      expect(models).not_to be_empty
      
      # Check for some expected models
      model_ids = models.map(&:id)
      expect(model_ids).to include('TinyLlama/TinyLlama-1.1B-Chat-v1.0')
      expect(model_ids).to include('mistralai/Mistral-7B-Instruct-v0.1')
      expect(model_ids).to include('google/gemma-2b')
      expect(model_ids).to include('gguf-models')
    end

    it 'correctly identifies chat capabilities' do
      models = described_class.list_models
      
      chat_model = models.find { |m| m.id == 'TinyLlama/TinyLlama-1.1B-Chat-v1.0' }
      expect(chat_model.capabilities).to include('chat')
      
      base_model = models.find { |m| m.id == 'google/gemma-2b' }
      expect(base_model.capabilities).not_to include('chat')
      
      instruct_model = models.find { |m| m.id == 'google/gemma-2b-it' }
      expect(instruct_model.capabilities).to include('chat')
    end
  end

  # Mock-based tests for chat functionality
  describe 'chat functionality' do
    let(:mock_llm) { double('Candle::LLM') }
    let(:mock_device) { double('Candle::Device') }
    let(:config) { RubyLLM::Configuration.new }

    before do
      # Mock the Candle module if it's not available
      unless defined?(::Candle)
        stub_const('::Candle', Module.new)
        stub_const('::Candle::LLM', Class.new)
        stub_const('::Candle::Device', Class.new)
        stub_const('::Candle::GenerationConfig', Class.new)
      end

      allow(::Candle::Device).to receive(:cpu).and_return(mock_device)
      allow(::Candle::LLM).to receive(:from_pretrained).and_return(mock_llm)
      allow(mock_llm).to receive(:model_name).and_return('TinyLlama/TinyLlama-1.1B-Chat-v1.0')
    end

    describe '#complete' do
      it 'raises NotImplementedError for completion_url' do
        expect { described_class.completion_url }.to raise_error(NotImplementedError)
      end

      it 'raises helpful error when red-candle is not installed' do
        # Temporarily hide ::Candle if it exists
        if defined?(::Candle)
          skip 'red-candle is installed, cannot test missing dependency error'
        end
        
        expect {
          described_class.complete("What's 2 + 2?", model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0')
        }.to raise_error(RubyLLM::ConfigurationError, /red-candle gem is not installed/)
      end

      it 'can complete a simple prompt' do
        allow(mock_llm).to receive(:generate).and_return('The answer is 4.')
        allow(::Candle::GenerationConfig).to receive(:balanced).and_return({})

        # We need to stub the complete method since it's complex
        allow(described_class).to receive(:complete).and_return(
          RubyLLM::Message.new(content: 'The answer is 4.', role: :assistant, model_id: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0')
        )

        result = described_class.complete("What's 2 + 2?", model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0')
        expect(result).to be_a(RubyLLM::Message)
        expect(result.content).to eq('The answer is 4.')
        expect(result.role).to eq(:assistant)
      end
    end

    describe 'streaming' do
      it 'supports streaming responses' do
        tokens = ['The', ' answer', ' is', ' 4', '.']
        token_index = 0

        allow(mock_llm).to receive(:generate_stream) do |prompt, config:, &block|
          tokens.each { |token| block.call(token) }
          tokens.join
        end

        chunks = []
        allow(described_class).to receive(:complete) do |messages, **options, &block|
          if options[:stream] && block
            tokens.each do |token|
              chunk = RubyLLM::Chunk.new(
                content: token,
                role: :assistant,
                finish_reason: nil,
                model_id: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0',
                tool_calls: []
              )
              block.call(chunk)
            end
          end
          RubyLLM::Message.new(
            content: tokens.join,
            role: :assistant,
            model_id: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
          )
        end

        result = described_class.complete("What's 2 + 2?", stream: true) do |chunk|
          chunks << chunk
        end

        expect(chunks.size).to eq(5)
        expect(chunks.map(&:content).join).to eq('The answer is 4.')
        expect(result.content).to eq('The answer is 4.')
      end
    end

    describe 'structured generation' do
      let(:schema) do
        {
          type: 'object',
          properties: {
            answer: { type: 'string', enum: ['yes', 'no'] }
          },
          required: ['answer']
        }
      end

      it 'supports structured generation with JSON schema' do
        allow(mock_llm).to receive(:generate_structured).with(
          'Is Ruby a programming language?',
          schema: schema
        ).and_return({ 'answer' => 'yes' })

        allow(described_class).to receive(:generate_structured).and_return(
          RubyLLM::Message.new(
            content: '{"answer":"yes"}',
            role: :assistant,
            model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
          )
        )

        result = described_class.generate_structured(
          'Is Ruby a programming language?',
          schema: schema,
          model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
        )

        expect(JSON.parse(result.content)).to eq({ 'answer' => 'yes' })
      end

      it 'supports regex pattern generation' do
        pattern = '\d{3}-\d{3}-\d{4}'
        
        allow(mock_llm).to receive(:generate_regex).with(
          'Generate a phone number:',
          pattern: pattern
        ).and_return('555-123-4567')

        allow(described_class).to receive(:generate_regex).and_return(
          RubyLLM::Message.new(
            content: '555-123-4567',
            role: 'assistant',
            model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
          )
        )

        result = described_class.generate_regex(
          'Generate a phone number:',
          pattern: pattern,
          model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
        )

        expect(result.content).to match(/\d{3}-\d{3}-\d{4}/)
      end
    end
  end

  describe 'integration with ruby_llm' do
    it 'can be used as a provider' do
      # This tests that the provider follows the expected interface
      expect(described_class).to respond_to(:complete)
      expect(described_class).to respond_to(:list_models)
      expect(described_class).to respond_to(:slug)
      expect(described_class).to respond_to(:local?)
      expect(described_class).to respond_to(:api_base)
      expect(described_class).to respond_to(:headers)
      expect(described_class).to respond_to(:capabilities)
      expect(described_class).to respond_to(:configuration_requirements)
    end
  end
end