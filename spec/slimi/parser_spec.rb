# frozen_string_literal: true

RSpec.describe Slimi::Parser do
  describe '#call' do
    subject do
      parser.call(source)
    end

    let(:parser) do
      described_class.new(
        attr_list_delims: {
          '(' => ')',
          '[' => ']',
          '{' => '}'
        },
        shortcut: {
          '#' => { attr: 'id' },
          '.' => { attr: 'class' },
          '?' => { tag: 'p' } # For testing tag shortcut (not attribute shortcut).
        }
      )
    end

    let(:source) do
      raise NotImplementedError
    end

    context 'with tag' do
      let(:source) do
        <<~SLIM
          p a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slim, :text, :inline, [:multi, [:slim, :interpolate, ' a']]]], [:newline]]
        )
      end
    end

    context 'with tag without content' do
      let(:source) do
        <<~SLIM
          p
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:multi, [:newline]]]]
        )
      end
    end

    context 'with tag with content' do
      let(:source) do
        <<~SLIM
          p
            | a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:multi, [:newline], [:slim, :text, :verbatim, [:multi, [:slim, :interpolate, 'a']]], [:newline]]]]
        )
      end
    end

    context 'with tag with output code' do
      let(:source) do
        <<~SLIM
          p= 1
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slim, :output, true, '1', [:multi, [:newline]]]]]
        )
      end
    end

    context 'with tag with output code with breaking lines' do
      let(:source) do
        <<~SLIM
          p= [,
          ]
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slim, :output, true, "[,\n]", [:multi, [:newline]]]]]
        )
      end
    end

    context 'with HTML comment' do
      let(:source) do
        <<~SLIM
          /! a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :comment, [:slim, :text, :verbatim, [:multi, [:slim, :interpolate, ' a']]]], [:newline]]
        )
      end
    end

    context 'with HTML conditional comment' do
      let(:source) do
        <<~SLIM
          /[if IE]
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :condcomment, 'if IE', [:multi, [:newline]]]]
        )
      end
    end

    context 'with slim comment' do
      let(:source) do
        <<~SLIM
          / a
          / b
            c
              d
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:newline], [:newline], [:newline], [:newline]]
        )
      end
    end

    context 'with verbatim text block' do
      let(:source) do
        <<~SLIM
          | a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slim, :text, :verbatim, [:multi, [:slim, :interpolate, 'a']]], [:newline]]
        )
      end
    end

    context 'with verbatim text block with trailing white space' do
      let(:source) do
        <<~SLIM
          ' a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slim, :text, :verbatim, [:multi, [:slim, :interpolate, 'a']]], [:static, ' '], [:newline]]
        )
      end
    end

    context 'with closed tag' do
      let(:source) do
        <<~SLIM
          img /
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'img', %i[html attrs]], [:newline]]
        )
      end
    end

    context 'with inline HTML' do
      let(:source) do
        <<~SLIM
          <hr>
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:multi, [:slim, :interpolate, '<hr>'], [:multi, [:newline]]]]
        )
      end
    end

    context 'with code block' do
      let(:source) do
        <<~SLIM
          - 1
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slim, :control, '1', [:multi, [:newline]]]]
        )
      end
    end

    context 'with output block' do
      let(:source) do
        <<~SLIM
          = 1
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slim, :output, true, '1', [:multi, [:newline]]]]
        )
      end
    end

    context 'with doctype' do
      let(:source) do
        <<~SLIM
          doctype html
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :doctype, 'html'], [:newline]]
        )
      end
    end

    context 'with shortcut attribute' do
      let(:source) do
        <<~SLIM
          div.a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:static, 'a']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with shortcut attribute without tag name' do
      let(:source) do
        <<~SLIM
          .a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:static, 'a']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with shortcut tag name' do
      let(:source) do
        <<~SLIM
          ?
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', %i[html attrs], [:multi, [:newline]]]]
        )
      end
    end

    context 'with shortcut tag name and shortcut attribute' do
      let(:source) do
        <<~SLIM
          ?.a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'p', [:html, :attrs, [:html, :attr, 'class', [:static, 'a']]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with quoted attribute' do
      let(:source) do
        <<~SLIM
          a href="http://example.com/"
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'a', [:html, :attrs, [:html, :attr, 'href', [:escape, true, [:slim, :interpolate, 'http://example.com/']]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with quoted attribute with attribute delimiter' do
      let(:source) do
        <<~SLIM
          a[href="http://example.com/"]
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'a', [:html, :attrs, [:html, :attr, 'href', [:escape, true, [:slim, :interpolate, 'http://example.com/']]]], [:multi, [:newline]]]]
        )
      end
    end
  end
end
