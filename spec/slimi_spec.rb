# frozen_string_literal: true

require 'slim'
require 'temple'

RSpec.describe Slimi do
  subject do
    template.new(template_options) { source }.render
  end

  let(:template) do
    Temple::Templates::Tilt(Slimi::Engine, register_as: 'slimi')
  end

  let(:template_options) do
    {}
  end

  context 'with double quote' do
    let(:source) do
      <<~SLIM
        p = "<strong>Hello World\\n, meet \\"Slim\\"</strong>."
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        "<p>&lt;strong&gt;Hello World\n, meet \&quot;Slim\&quot;&lt;/strong&gt;.</p>"
      )
    end
  end

  context 'with single quote' do
    let(:source) do
      <<~SLIM
        p = "<strong>Hello World\\n, meet 'Slim'</strong>."
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        "<p>&lt;strong&gt;Hello World\n, meet &#39;Slim&#39;&lt;/strong&gt;.</p>"
      )
    end
  end

  context 'with html_safe' do
    before do
      template_options[:use_html_safe] = true
      allow_any_instance_of(String).to receive(:html_safe?).and_return(true)
    end

    let(:source) do
      <<~SLIM
        p = "<strong>Hello World\\n, meet \\"Slim\\"</strong>."
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        "<p><strong>Hello World\n, meet \"Slim\"</strong>.</p>"
      )
    end
  end

  context 'with non-do control' do
    let(:source) do
      <<~'SLIM'
        - 2.times
          | Hello
      SLIM
    end

    it 'returns expected s-expression' do
      is_expected.to eq(
        'Hello' * 2
      )
    end
  end

  context 'with non-do output' do
    let(:source) do
      <<~'SLIM'
        = 'foo'.gsub(/o/)
          | a
      SLIM
    end

    it 'returns expected s-expression' do
      is_expected.to eq(
        'faa'
      )
    end
  end
end
