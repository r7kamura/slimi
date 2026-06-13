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
      <<~SLIM,
        p a
      SLIM
      <<~HTML
        <p>a</p>
      HTML
    ],
    [
      'tag without content',
      <<~SLIM,
        p
      SLIM
      <<~HTML
        <p></p>
      HTML
    ],
    [
      'tag with indented content',
      <<~SLIM,
        p
          | a
      SLIM
      <<~HTML
        <p>a</p>
      HTML
    ],
    [
      'double quote in output',
      <<~SLIM,
        = '"'
      SLIM
      <<~HTML
        &quot;
      HTML
    ],
    [
      'single quote in output',
      <<~SLIM,
        = "'"
      SLIM
      <<~HTML
        &#39;
      HTML
    ],
    [
      'shortcut attribute',
      <<~SLIM,
        div.a
      SLIM
      <<~HTML
        <div class="a"></div>
      HTML
    ],
    [
      'shortcut attribute without tag',
      <<~SLIM,
        .a
      SLIM
      <<~HTML
        <div class="a"></div>
      HTML
    ],
    [
      'code attribute',
      <<~SLIM,
        div a=1+1
      SLIM
      <<~HTML
        <div a="2"></div>
      HTML
    ],
    [
      'Array code attribute with mergable attribute name',
      <<~SLIM,
        div class=(%w[a b c])
      SLIM
      <<~HTML
        <div class="a b c"></div>
      HTML
    ],
    [
      'do-less control',
      <<~SLIM,
        - 2.times
          | a
      SLIM
      <<~HTML
        aa
      HTML
    ],
    [
      'do-less output',
      <<~SLIM,
        = 'foo'.gsub(/o/)
          | a
      SLIM
      <<~HTML
        faa
      HTML
    ],
    [
      'end-less if',
      <<~SLIM,
        - if true
          | a
      SLIM
      <<~HTML
        a
      HTML
    ],
    [
      'splat attribute with hash literal',
      <<~SLIM,
        div *{ "id" => "foo", "class" => "bar" }
      SLIM
      <<~HTML
        <div class="bar" id="foo"></div>
      HTML
    ],
    [
      'splat attribute merged with shortcut and static attributes',
      <<~SLIM,
        div.a *{ "class" => "b" } id="x"
      SLIM
      <<~HTML
        <div class="a b" id="x"></div>
      HTML
    ],
    [
      'splat attribute with boolean values',
      <<~SLIM,
        div *{ "disabled" => true, "checked" => false, "name" => nil }
      SLIM
      <<~HTML
        <div disabled=""></div>
      HTML
    ],
    [
      'splat attribute with value containing special characters',
      <<~SLIM,
        div *{ "title" => "a&b" }
      SLIM
      <<~HTML
        <div title="a&amp;b"></div>
      HTML
    ],
    [
      'splat attribute with escaped sibling attribute',
      <<~SLIM,
        div *{ "k" => "v" } id="a&b"
      SLIM
      <<~HTML
        <div id="a&amp;b" k="v"></div>
      HTML
    ],
    [
      'splat attribute with unescaped sibling attribute',
      <<~SLIM,
        div *{ "k" => "v" } id=="<raw>"
      SLIM
      <<~HTML
        <div id="<raw>" k="v"></div>
      HTML
    ],
    [
      'splat attribute with false and nil sibling attributes',
      <<~SLIM,
        div *{ "k" => "v" } data-x=false data-y=nil
      SLIM
      <<~HTML
        <div k="v"></div>
      HTML
    ],
    [
      'splat attribute with true sibling attribute',
      <<~SLIM,
        div *{ "k" => "v" } data-x=true
      SLIM
      <<~HTML
        <div data-x="" k="v"></div>
      HTML
    ],
    [
      'splat attribute with mergeable array sibling attribute',
      <<~SLIM,
        div *{ "k" => "v" } class=["a", "b"]
      SLIM
      <<~HTML
        <div class="a b" k="v"></div>
      HTML
    ],
    [
      'splat attribute with boolean sibling attribute',
      <<~SLIM,
        div(*{ "k" => "v" } disabled)
      SLIM
      <<~HTML
        <div disabled="" k="v"></div>
      HTML
    ],
    [
      'splat attribute with nested hash value',
      <<~SLIM,
        div *{ "data" => { "a" => 1 } }
      SLIM
      <<~HTML
        <div data-a="1"></div>
      HTML
    ],
    [
      'splat attribute with mergeable array value containing nil and empty values',
      <<~SLIM,
        div *{ "class" => [nil, "a", ""] }
      SLIM
      <<~HTML
        <div class="a"></div>
      HTML
    ],
    [
      'splat attribute on a tag after a tag with mergeable attribute',
      <<~SLIM,
        div class=["x"]
        div *{ "k" => "v" } id=[1, 2]
      SLIM
      <<~HTML
        <div class="x"></div><div id="[1, 2]" k="v"></div>
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
      <<~SLIM
        = '"'
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '"'
      )
    end
  end

  context 'with splat attribute from a method returning a hash' do
    subject do
      scope = Object.new
      scope.define_singleton_method(:foo) { { 'id' => 'a', 'class' => 'y' } }
      template.new(template_options) { source }.render(scope)
    end

    let(:source) do
      <<~SLIM
        div.x *foo class="z"
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '<div class="x y z" id="a"></div>'
      )
    end
  end

  context 'with splat attribute producing an invalid attribute name' do
    let(:source) do
      <<~SLIM
        div *{ "a b" => "c" }
      SLIM
    end

    it 'raises an error at render time' do
      expect { subject }.to raise_error(Slimi::Errors::InvalidAttributeNameError)
    end
  end

  context 'with splat attribute conflicting with an unmergeable attribute' do
    let(:source) do
      <<~SLIM
        div id="x" *{ "id" => "y" }
      SLIM
    end

    it 'raises an error at render time' do
      expect { subject }.to raise_error(Slimi::Errors::MultipleAttributesError)
    end
  end

  context 'with splat attribute and boolean sibling attribute in html format' do
    before do
      template_options[:format] = :html
    end

    let(:source) do
      <<~SLIM
        div(*{ "k" => "v" } disabled)
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '<div disabled k="v"></div>'
      )
    end
  end

  context 'with splat attribute with html_safe value' do
    before do
      template_options[:use_html_safe] = true
      allow_any_instance_of(String).to receive(:html_safe?).and_return(true)
    end

    let(:source) do
      <<~SLIM
        div *{ "title" => "a&b" }
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '<div title="a&b"></div>'
      )
    end
  end

  context 'with splat attribute with html_safe value and disabled use_html_safe option' do
    before do
      template_options[:use_html_safe] = false
      allow_any_instance_of(String).to receive(:html_safe?).and_return(true)
    end

    let(:source) do
      <<~SLIM
        div *{ "title" => "a&b" }
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '<div title="a&amp;b"></div>'
      )
    end
  end

  context 'with preamble and postamble options' do
    before do
      template_options[:preamble] = '1'
      template_options[:postamble] = '3'
    end

    let(:source) do
      <<~SLIM
        | 2
      SLIM
    end

    it 'returns expected HTML' do
      is_expected.to eq(
        '123'
      )
    end
  end
end
