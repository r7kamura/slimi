# frozen_string_literal: true

RSpec.describe Slimi::Parser do
  describe '#call' do
    subject do
      parser.call(source)
    end

    let(:file_path) do
      'example.html.slim'
    end

    let(:parser) do
      described_class.new(
        file: file_path,
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
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slimi, :text, :inline, [:multi, [:slimi, :interpolate, 2, 3, 'a']]]], [:newline]]
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
          [:multi, [:html, :tag, 'p', %i[html attrs], [:multi, [:newline], [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 6, 7, 'a']]], [:newline]]]]
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
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slimi, :position, 3, 4, [:slimi, :output, true, '1', [:multi, [:newline]]]]]]
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
          [:multi, [:html, :tag, 'p', %i[html attrs], [:slimi, :position, 3, 7, [:slimi, :output, true, "[,\n]", [:multi, [:newline]]]]]]
        )
      end
    end

    # rubocop:disable Layout/TrailingWhitespace
    context 'with output code with comma followed by space for line continuation' do
      let(:source) do
        <<~SLIM
          = label_tag :label, 
            "Label"
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slimi, :position, 2, 30, [:slimi, :output, true, "label_tag :label, \n  \"Label\"", [:multi, [:newline]]]]]
        )
      end
    end
    # rubocop:enable Layout/TrailingWhitespace

    context 'with HTML comment' do
      let(:source) do
        <<~SLIM
          /! a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :comment, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 3, 4, 'a']]]], [:newline]]
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
          [:multi, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 3, 'a']]], [:newline]]
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
          [:multi, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 3, 'a']]], [:static, ' '], [:newline]]
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
          [:multi, [:multi, [:slimi, :interpolate, 0, 4, '<hr>'], [:multi, [:newline]]]]
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
          [:multi, [:slimi, :position, 2, 3, [:slimi, :control, '1', [:multi, [:newline]]]]]
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
          [:multi, [:slimi, :position, 2, 3, [:slimi, :output, true, '1', [:multi, [:newline]]]]]
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

    context 'with Ruby attribute' do
      let(:source) do
        <<~SLIM
          div class=a
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:slimi, :position, 10, 11, [:slimi, :attrvalue, true, 'a']]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with Ruby attribute with parentheses' do
      let(:source) do
        <<~SLIM
          div class=a(b)
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:slimi, :position, 10, 14, [:slimi, :attrvalue, true, 'a(b)']]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with multi-line attribute' do
      let(:source) do
        <<~SLIM
          div[
            class="a"
          ]
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:newline], [:newline], [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'class', [:escape, true, [:slimi, :interpolate, 14, 15, 'a']]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with multi-line attribute and missing attribute closing delimiter' do
      let(:source) do
        <<~SLIM
          div[
            class="a"
        SLIM
      end

      it 'returns expected s-expression' do
        expect { subject }.to raise_error(Slimi::Errors::AttributeClosingDelimiterNotFoundError)
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
          [:multi, [:html, :tag, 'a', [:html, :attrs, [:html, :attr, 'href', [:escape, true, [:slimi, :interpolate, 8, 27, 'http://example.com/']]]], [:multi, [:newline]]]]
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
          [:multi, [:html, :tag, 'a', [:html, :attrs, [:html, :attr, 'href', [:escape, true, [:slimi, :interpolate, 8, 27, 'http://example.com/']]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with quoted attribute with quotes in interpolation' do
      let(:source) do
        <<~'SLIM'
          div a="{#{"b"}}"
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', [:html, :attrs, [:html, :attr, 'a', [:escape, true, [:slimi, :interpolate, 7, 15, "{\#{\"b\"}}"]]]], [:multi, [:newline]]]]
        )
      end
    end

    context 'with interpolation' do
      let(:source) do
        <<~'SLIM'
          | #{a}
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slimi, :text, :verbatim, [:multi, [:slimi, :interpolate, 2, 6, '#{a}']]], [:newline]]
        )
      end
    end

    context 'with embedded template' do
      let(:source) do
        <<~SLIM
          ruby:
            1
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slimi, :embedded, 'ruby', [:multi, [:newline], [:slimi, :interpolate, 8, 9, '1']], %i[html attrs]], [:newline]]
        )
      end
    end

    context 'with empty line between nested lines' do
      let(:source) do
        <<~SLIM
          div
            div
              div

            div
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:html, :tag, 'div', %i[html attrs], [:multi, [:newline], [:html, :tag, 'div', %i[html attrs], [:multi, [:newline], [:html, :tag, 'div', %i[html attrs], [:multi, [:newline], [:newline]]]]], [:html, :tag, 'div', %i[html attrs], [:multi, [:newline]]]]]]
        )
      end
    end

    context 'with empty line between embedded template' do
      let(:source) do
        <<~SLIM
          javascript:
            a

            b
        SLIM
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slimi, :embedded, 'javascript', [:multi, [:newline], [:slimi, :interpolate, 14, 15, 'a'], [:newline], [:newline], [:slimi, :interpolate, 19, 20, 'b']], %i[html attrs]], [:newline]]
        )
      end
    end

    context 'with CR+LF with code block' do
      let(:source) do
        "- a\r\n"
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:slimi, :position, 2, 3, [:slimi, :control, 'a', [:multi, [:newline]]]]]
        )
      end
    end

    context 'with CR+LF empty line' do
      let(:source) do
        "\r\n\r\n"
      end

      it 'returns expected s-expression' do
        is_expected.to eq(
          [:multi, [:newline], [:newline]]
        )
      end
    end

    context 'with unknown line indicator' do
      let(:source) do
        <<~SLIM
          $
        SLIM
      end

      it 'raises expected error' do
        expect { subject }.to raise_error(Slimi::Errors::UnknownLineIndicatorError) { |error|
          expect(error.to_s).to include(file_path)
        }
      end
    end
  end
end
