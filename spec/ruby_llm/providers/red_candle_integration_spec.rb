# frozen_string_literal: true

require 'spec_helper'

# Integration tests that run when red-candle gem is available
# These are skipped in CI unless the gem is installed
RSpec.describe 'RedCandle Integration', skip: !defined?(Candle) do
  include_context 'with configured RubyLLM'

  # Add red-candle to the test models if the gem is available
  RED_CANDLE_TEST_MODELS = [
    { provider: :red_candle, model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0' }
  ].freeze

  before do
    # Configure red-candle settings
    RubyLLM.configure do |config|
      config.red_candle_device = 'cpu' # Use CPU for tests
      config.red_candle_default_model = 'TinyLlama/TinyLlama-1.1B-Chat-v1.0'
    end
  end

  describe 'basic chat functionality' do
    RED_CANDLE_TEST_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      
      it "#{provider}/#{model} can have a basic conversation" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to be_a(String)
        expect(response.content).not_to be_empty
        expect(response.role).to eq(:assistant)
        # Red-candle doesn't track tokens by default
        expect(response.model).to eq(model)
      end

      it "#{provider}/#{model} can handle multi-turn conversations" do
        chat = RubyLLM.chat(model: model, provider: provider)

        first = chat.ask("Remember the number 42.")
        expect(first.content).to be_a(String)

        followup = chat.ask("What number did I ask you to remember?")
        expect(followup.content).to include('42')
      end

      it "#{provider}/#{model} successfully uses the system prompt" do
        chat = RubyLLM.chat(model: model, provider: provider)
        chat.with_instructions 'You are a helpful assistant who always mentions the word "banana" in responses.'

        response = chat.ask('Tell me about programming.')
        expect(response.content.downcase).to include('banana')
      end
    end
  end

  describe 'streaming responses' do
    RED_CANDLE_TEST_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      
      it "#{provider}/#{model} supports streaming responses" do
        chat = RubyLLM.chat(model: model, provider: provider)
        chunks = []

        response = chat.ask("Count from 1 to 3.") do |chunk|
          chunks << chunk
          expect(chunk).to be_a(RubyLLM::Chunk)
          expect(chunk.content).to be_a(String)
        end

        expect(chunks).not_to be_empty
        expect(response).to be_a(RubyLLM::Message)
        expect(response.content).to be_a(String)
        
        # The full response should contain the concatenated chunks
        full_content = chunks.map(&:content).join
        expect(response.content).to eq(full_content)
      end
    end
  end

  describe 'structured generation' do
    RED_CANDLE_TEST_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      
      it "#{provider}/#{model} supports JSON schema constraints" do
        chat = RubyLLM.chat(model: model, provider: provider)
        
        schema = {
          type: 'object',
          properties: {
            sentiment: { type: 'string', enum: ['positive', 'negative', 'neutral'] },
            confidence: { type: 'number', minimum: 0, maximum: 1 }
          },
          required: ['sentiment']
        }

        response = chat
          .with_schema(schema)
          .ask("What's the sentiment of: 'I love Ruby programming!'")

        expect(response.content).to be_a(Hash)
        expect(response.content['sentiment']).to be_in(['positive', 'negative', 'neutral'])
        expect(response.content['sentiment']).to eq('positive') # Should detect positive sentiment
        
        if response.content['confidence']
          expect(response.content['confidence']).to be_between(0, 1)
        end
      end
    end
  end

  describe 'model management' do
    it 'lists available models' do
      models = RubyLLM::Providers::RedCandle.list_models
      expect(models).to be_an(Array)
      expect(models).not_to be_empty
      
      # Check that TinyLlama is in the list
      tinyllama = models.find { |m| m.id == 'TinyLlama/TinyLlama-1.1B-Chat-v1.0' }
      expect(tinyllama).not_to be_nil
      expect(tinyllama.provider).to eq('red_candle')
      expect(tinyllama.capabilities).to include('chat', 'completion', 'structured_output')
    end
  end

  describe 'device configuration' do
    it 'respects device configuration' do
      RubyLLM.configure do |config|
        config.red_candle_device = 'cpu'
      end

      chat = RubyLLM.chat(model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0', provider: :red_candle)
      response = chat.ask("Hello!")
      
      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).not_to be_empty
    end

    it 'uses Metal device when available and configured', skip: !RbConfig::CONFIG['host_os'].match?(/darwin/) do
      RubyLLM.configure do |config|
        config.red_candle_device = 'metal'
      end

      chat = RubyLLM.chat(model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0', provider: :red_candle)
      response = chat.ask("Hello!")
      
      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).not_to be_empty
    end
  end

  describe 'GGUF model support' do
    it 'can load GGUF quantized models', skip: 'Requires GGUF file download' do
      # This test would require downloading a GGUF file first
      # In a real test suite, you might have a small test GGUF file
      chat = RubyLLM.chat(
        model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
        provider: :red_candle
      )
      
      response = chat.ask("Hello!")
      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).not_to be_empty
    end
  end

  describe 'error handling' do
    it 'raises appropriate error for non-existent models' do
      expect {
        chat = RubyLLM.chat(model: 'non-existent/model', provider: :red_candle)
        chat.ask("Hello!")
      }.to raise_error(StandardError) # The specific error depends on red-candle implementation
    end

    it 'handles invalid device configuration gracefully' do
      RubyLLM.configure do |config|
        config.red_candle_device = 'invalid-device'
      end

      # Should fall back to CPU or raise a clear error
      chat = RubyLLM.chat(model: 'TinyLlama/TinyLlama-1.1B-Chat-v1.0', provider: :red_candle)
      response = chat.ask("Hello!")
      
      expect(response).to be_a(RubyLLM::Message)
    end
  end
end