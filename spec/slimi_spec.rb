# frozen_string_literal: true

require 'slim'

RSpec.describe Slimi do
  subject do
    template.new(template_options) { source }.render
  end

  let(:template) do
    Temple::Templates::Tilt(engine_class, register_as: 'slimi')
  end

  let(:template_options) do
    {}
  end

  let(:engine_class) do
    Class.new(Temple::Engine) do
      define_options(
        attr_quote: '"',
        default_tag: 'div',
        format: :xhtml,
        merge_attrs: { 'class' => ' ' },
        pretty: false,
        sort_attrs: true
      )

      use Slimi::Parser

      use Slim::Embedded
      use Slim::Interpolation
      use Slim::Splat::Filter
      use Slim::DoInserter
      use Slim::EndInserter
      use Slim::Controls
      html :AttributeSorter
      html :AttributeMerger
      use Slim::CodeAttributes
      use(:AttributeRemover) { Temple::HTML::AttributeRemover.new(remove_empty_attrs: options[:merge_attrs].keys) }
      html :Pretty
      filter :Escapable
      filter :ControlFlow
      filter :MultiFlattener
      filter :StaticMerger
      generator :StringBuffer
    end
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
end
