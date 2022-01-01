# frozen_string_literal: true

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

  [
    [
      'tag with content',
      <<~'SLIM',
        p a
      SLIM
      <<~HTML
        <p>a</p>
      HTML
    ],
    [
      'tag without content',
      <<~'SLIM',
        p
      SLIM
      <<~HTML
        <p></p>
      HTML
    ],
    [
      'tag with indented content',
      <<~'SLIM',
        p
          | a
      SLIM
      <<~HTML
        <p>a</p>
      HTML
    ],
    [
      'double quote in output',
      <<~'SLIM',
        = '"'
      SLIM
      <<~HTML
        &quot;
      HTML
    ],
    [
      'single quote in output',
      <<~'SLIM',
        = "'"
      SLIM
      <<~HTML
        &#39;
      HTML
    ],
    [
      'do-less control',
      <<~'SLIM',
        - 2.times
          | a
      SLIM
      <<~HTML
        aa
      HTML
    ],
    [
      'do-less output',
      <<~'SLIM',
        = 'foo'.gsub(/o/)
          | a
      SLIM
      <<~HTML
        faa
      HTML
    ],
    [
      'end-less if',
      <<~'SLIM',
        - if true
          | a
      SLIM
      <<~HTML
        a
      HTML
    ]
  ].each do |(name, slim, html)|
    context "with #{name}" do
      let(:source) do
        slim
      end

      it 'returns expected HTML' do
        is_expected.to eq(html.delete_suffix("\n"))
      end
    end
  end

  context 'with double quote in html_safe String' do
    before do
      template_options[:use_html_safe] = true
      allow_any_instance_of(String).to receive(:html_safe?).and_return(true)
    end

    let(:source) do
      <<~'SLIM'
        = '"'
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '"'
      )
    end
  end
end
