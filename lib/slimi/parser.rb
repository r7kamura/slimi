# frozen_string_literal: true

require 'strscan'
require 'temple'

module Slimi
  class Parser < ::Temple::Parser
    define_options(
      :file,
      attr_list_delims: {
        '(' => ')',
        '[' => ']',
        '{' => '}'
      },
      code_attr_delims: {
        '(' => ')',
        '[' => ']',
        '{' => '}'
      },
      shortcut: {
        '#' => { attr: 'id' },
        '.' => { attr: 'class' }
      }
    )

    def initialize(_options = {})
      super
      @file_path = options[:file] || '(__TEMPLATE__)'
      factory = Factory.new(
        attribute_delimiters: options[:attr_list_delims] || {},
        default_tag: options[:default_tag] || 'div',
        ruby_attribute_delimiters: options[:code_attr_delims] || {},
        shortcut: options[:shortcut] || {}
      )
      @attribute_delimiters = factory.attribute_delimiters
      @attribute_shortcuts = factory.attribute_shortcuts
      @tag_shortcuts = factory.tag_shortcuts
      @attribute_shortcut_regexp = factory.attribute_shortcut_regexp
      @attribute_delimiter_regexp = factory.attribute_delimiter_regexp
      @quoted_attribute_regexp = factory.quoted_attribute_regexp
      @tag_name_regexp = factory.tag_name_regexp
      @attribute_name_regexp = factory.attribute_name_regexp
      @ruby_attribute_regexp = factory.ruby_attribute_regexp
      @ruby_attribute_delimiter_regexp = factory.ruby_attribute_delimiter_regexp
      @ruby_attribute_delimiters = factory.ruby_attribute_delimiters
      @embedded_template_regexp = factory.embedded_template_regexp
    end

    def call(source)
      @stacks = [[:multi]]
      @indents = []
      @scanner = ::StringScanner.new(source)
      parse_block until @scanner.eos?
      @stacks[0]
    end

    private

    def parse_block
      return if parse_blank_line

      parse_indent

      parse_html_comment ||
        parse_html_conditional_comment ||
        parse_slim_comment_block ||
        parse_verbatim_text_block ||
        parse_inline_html ||
        parse_code_block ||
        parse_output_block ||
        parse_embedded_template ||
        parse_doctype ||
        parse_tag ||
        syntax_error!(Errors::UnknownLineIndicatorError)
    end

    # Parse blank line.
    # @return [Boolean] True if it could parse a blank line.
    def parse_blank_line
      if @scanner.skip(/[ \t]*(?=\R|$)/)
        parse_line_ending
        true
      else
        false
      end
    end

    def parse_indent
      @scanner.skip(/[ \t]*/)
      indent = indent_from_last_match
      @indents << indent if @indents.empty?

      if indent > @indents.last
        syntax_error!(Errors::UnexpectedIndentationError) unless expecting_indentation?

        @indents << indent
      else
        @stacks.pop if expecting_indentation?

        while indent < @indents.last && @indents.length > 1
          @indents.pop
          @stacks.pop
        end

        syntax_error!(Errors::MalformedIndentationError) if indent != @indents.last
      end
    end

    # Parse embedded template lines.
    #   e.g.
    #     ruby:
    #       a = b + c
    def parse_embedded_template
      return unless @scanner.skip(@embedded_template_regexp)

      embedded_template_engine_name = @scanner[1]
      attributes = parse_attributes
      @stacks.last << [:slimi, :embedded, embedded_template_engine_name, parse_text_block, attributes]
    end

    # @return [Boolean]
    def parse_tag
      parse_tag_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_tag_inner
      tag_name = parse_tag_name
      if tag_name
        attributes = parse_attributes

        white_space_marker = @scanner.scan(/[<>']*/)
        with_trailing_white_space = white_space_marker.include?('<') || white_space_marker.include?("'")
        with_leading_white_space = white_space_marker.include?('>')

        tag = [:html, :tag, tag_name, attributes]
        @stacks.last << [:static, ' '] if with_leading_white_space
        @stacks.last << tag
        @stacks.last << [:static, ' '] if with_trailing_white_space

        if @scanner.skip(/[ \t]*(?=\R|$)/)
          content = [:multi]
          tag << content
          @stacks << content
        elsif @scanner.skip(/[ \t]*=(=?)([<>'])*/)
          escape = @scanner[1].empty?
          white_space_marker = @scanner[2]
          with_trailing_white_space2 = !with_trailing_white_space && white_space_marker && (white_space_marker.include?('<') || white_space_marker.include?("'"))
          with_leading_white_space2 = !with_leading_white_space && white_space_marker && white_space_marker.include?('>')
          block = [:multi]
          @stacks.last.insert(-2, [:static, ' ']) if with_leading_white_space2
          @scanner.skip(/[ \t]+/)
          tag << with_position { [:slimi, :output, escape, parse_broken_lines, block] }
          @stacks.last << [:static, ' '] if with_trailing_white_space2
          @stacks << block
        elsif @scanner.skip(%r{[ \t]*/[ \t]*})
          syntax_error!(Errors::UnexpectedTextAfterClosedTagError) unless @scanner.match?(/\r?\n/)
        else
          @scanner.skip(/[ \t]+/)
          tag << [:slimi, :text, :inline, parse_text_block]
        end
        true
      else
        false
      end
    end

    # Parse tag name part.
    #   e.g. div.foo
    #        ^^^
    #           `- tag name
    #   e.g. .foo
    #        ^
    #         `- tag name shortcut (not consume input in this case)
    #   e.g. ?.foo
    #        ^
    #         `- tag name shortcut if `?` is registered as only-tag shortcut (consume input in this case)
    # @return [String, nil] Tag name if found.
    def parse_tag_name
      return unless @scanner.match?(@tag_name_regexp)

      if @scanner[1]
        @scanner.pos += @scanner.matched_size
        @scanner.matched
      else
        marker = @scanner.matched
        @scanner.pos += @scanner.matched_size unless @attribute_shortcuts[marker]
        @tag_shortcuts[marker]
      end
    end

    # Parse attribute shortcuts part.
    #   e.g. div#foo.bar
    #           ^^^^^^^^
    #                   `- attribute shortcuts
    # @return [Array] Found attribute s-expressions.
    def parse_tag_attribute_shortcuts
      result = []
      while @scanner.skip(@attribute_shortcut_regexp)
        marker = @scanner[1]
        attribute_value = @scanner[2]
        attribute_names = @attribute_shortcuts[marker]
        attribute_names.map do |attribute_name|
          result << [:html, :attr, attribute_name.to_s, [:static, attribute_value]]
        end
      end
      result
    end

    # Parse quoted attribute value part.
    #   e.g. input type="text"
    #                   ^^^^^^
    #                         `- quoted attribute value
    # @note Skip closing quote in {}.
    # @param [String] quote `"'"` or `'"'`.
    # @return [Array] S-expression.
    def parse_quoted_attribute_value(quote)
      begin_ = @scanner.charpos
      end_ = nil
      value = +''
      count = 0
      loop do
        if @scanner.match?(/#{quote}/)
          if count.zero?
            end_ = @scanner.charpos
            @scanner.pos += @scanner.matched_size
            break
          else
            @scanner.pos += @scanner.matched_size
            value << @scanner.matched
          end
        elsif @scanner.skip(/\{/)
          count += 1
          value << @scanner.matched
        elsif @scanner.skip(/\}/)
          count -= 1
          value << @scanner.matched
        else
          value << @scanner.scan(/[^{}#{quote}]*/)
        end
      end
      [:slimi, :interpolate, begin_, end_, value]
    end

    # Parse attributes part.
    #   e.g. input type="text" value="a" autofocus
    #              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    #                                             `- attributes part
    # @return [Array] S-expression of attributes.
    def parse_attributes
      attributes = %i[html attrs]
      attributes += parse_tag_attribute_shortcuts

      if @scanner.scan(@attribute_delimiter_regexp)
        attribute_delimiter_opening = @scanner[1]
        attribute_delimiter_closing = @attribute_delimiters[attribute_delimiter_opening]
        attribute_delimiter_closing_regexp = ::Regexp.escape(attribute_delimiter_closing)
        boolean_attribute_regexp = /#{@attribute_name_regexp}(?=(?:[ \t]|#{attribute_delimiter_closing_regexp}|(?=\R|$)))/
        attribute_delimiter_closing_part_regexp = /[ \t]*#{attribute_delimiter_closing_regexp}/
      end

      # TODO: Support splat attributes.
      loop do
        if @scanner.skip(@quoted_attribute_regexp)
          attribute_name = @scanner[1]
          escape = @scanner[2].empty?
          quote = @scanner[3]
          attributes << [:html, :attr, attribute_name, [:escape, escape, parse_quoted_attribute_value(quote)]]
        elsif @scanner.skip(@ruby_attribute_regexp)
          attribute_name = @scanner[1]
          escape = @scanner[2].empty?
          charpos = @scanner.charpos
          attribute_value = parse_ruby_attribute_value(attribute_delimiter_closing)
          syntax_error!(Errors::InvalidEmptyAttributeError) if attribute_value.empty?
          attributes << [:html, :attr, attribute_name, [:slimi, :position, charpos, charpos + attribute_value.length, [:slimi, :attrvalue, escape, attribute_value]]]
        elsif !attribute_delimiter_closing_part_regexp
          break
        elsif @scanner.skip(boolean_attribute_regexp)
          attributes << [:html, :attr, @scanner[1], [:multi]]
        elsif @scanner.skip(attribute_delimiter_closing_part_regexp) # rubocop:disable Lint/DuplicateBranch
          break
        else
          @scanner.skip(/[ \t]+/)
          expect_line_ending

          syntax_error!(Errors::AttributeClosingDelimiterNotFoundError) if @scanner.eos?
        end
      end

      attributes
    end

    # Parse Ruby attribute value part.
    #   e.g. div class=foo
    #                  ^^^
    #                     `- Ruby attribute value
    # @param [String] attribute_delimiter_closing
    # @return [String]
    def parse_ruby_attribute_value(attribute_delimiter_closing)
      ending_regexp = /\s/
      ending_regexp = ::Regexp.union(ending_regexp, attribute_delimiter_closing) if attribute_delimiter_closing
      count = 0
      attribute_value = +''
      opening_delimiter = nil
      closing_delimiter = nil
      loop do
        break if count.zero? && @scanner.match?(ending_regexp)

        if @scanner.skip(/([,\\])\r?\n/)
          attribute_value << @scanner[1] << "\n"
        else
          if count.positive?
            if opening_delimiter && @scanner.match?(/#{::Regexp.escape(opening_delimiter)}/)
              count += 1
            elsif closing_delimiter && @scanner.match?(/#{::Regexp.escape(closing_delimiter)}/)
              count -= 1
            end
          elsif @scanner.match?(@ruby_attribute_delimiter_regexp)
            count = 1
            opening_delimiter = @scanner.matched
            closing_delimiter = @ruby_attribute_delimiters[opening_delimiter]
          end
          if (character = @scanner.scan(/[^\r\n]/))
            attribute_value << character
          end
        end
      end
      syntax_error!(Errors::RubyAttributeClosingDelimiterNotFoundError) if count != 0

      attribute_value
    end

    # @return [Boolean]
    def parse_html_comment
      if @scanner.skip(%r{/![ \t]*})
        text_block = parse_text_block
        text = [:slimi, :text, :verbatim, text_block]
        @stacks.last << [:html, :comment, text]
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_html_conditional_comment
      parse_html_conditional_comment_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_html_conditional_comment_inner
      if @scanner.skip(%r{/\[\s*(.*?)\s*\][ \t]*})
        block = [:multi]
        @stacks.last << [:html, :condcomment, @scanner[1], block]
        @stacks << block
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_slim_comment_block
      if @scanner.skip(%r{/[^\r\n]*})
        while !@scanner.eos? && (@scanner.match?(/[ \t]*(?=\R|$)/) || peek_indent > @indents.last)
          @scanner.skip(/[^\r\n]*/)
          parse_line_ending
        end
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_verbatim_text_block
      parse_verbatim_text_block_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_verbatim_text_block_inner
      if @scanner.skip(/([|']) ?/)
        with_trailing_white_space = @scanner[1] == "'"
        @stacks.last << [:slimi, :text, :verbatim, parse_text_block]
        @stacks.last << [:static, ' '] if with_trailing_white_space
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_inline_html
      parse_inline_html_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_inline_html_inner
      if @scanner.match?(/<[^\r\n]*/)
        begin_ = @scanner.charpos
        value = @scanner.matched
        @scanner.pos += @scanner.matched_size
        end_ = @scanner.charpos
        block = [:multi]
        @stacks.last << [:multi, [:slimi, :interpolate, begin_, end_, value], block]
        @stacks << block
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_code_block
      parse_code_block_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_code_block_inner
      if @scanner.skip(/-/)
        block = [:multi]
        @scanner.skip(/[ \t]+/)
        @stacks.last << with_position { [:slimi, :control, parse_broken_lines, block] }
        @stacks << block
        true
      else
        false
      end
    end

    # @return [Boolean]
    def parse_output_block
      parse_output_block_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_output_block_inner
      if @scanner.skip(/=(=?)([<>']*)/)
        escape = @scanner[1].empty?
        white_space_marker = @scanner[2]
        with_trailing_white_space = white_space_marker.include?('<') || white_space_marker.include?("'")
        with_leading_white_space = white_space_marker.include?('>')
        block = [:multi]
        @stacks.last << [:static, ' '] if with_trailing_white_space
        @scanner.skip(/[ \t]+/)
        @stacks.last << with_position { [:slimi, :output, escape, parse_broken_lines, block] }
        @stacks.last << [:static, ' '] if with_leading_white_space
        @stacks << block
      else
        false
      end
    end

    # @return [Boolean]
    def parse_doctype
      parse_doctype_inner && expect_line_ending
    end

    # @return [Boolean]
    def parse_doctype_inner
      if @scanner.skip(/doctype[ \t]*/)
        @stacks.last << [:html, :doctype, @scanner.scan(/.*/).rstrip]
        true
      else
        false
      end
    end

    # @return [Boolean]
    def expecting_indentation?
      @stacks.length > @indents.length
    end

    # @raise
    def expect_line_ending
      parse_line_ending || @scanner.eos? || syntax_error!(Errors::LineEndingNotFoundError)
    end

    # @return [Integer] Indent level.
    def peek_indent
      @scanner.match?(/[ \t]*/)
      indent_from_last_match
    end

    # @return [Integer]
    def indent_from_last_match
      @scanner.matched.chars.map do |char|
        case char
        when "\t"
          4
        when ' '
          1
        else
          0
        end
      end.sum
    end

    # @return [Boolean]
    def parse_line_ending
      if @scanner.skip(/\r?\n/)
        @stacks.last << [:newline]
        true
      else
        false
      end
    end

    # @todo Append new_line for each empty line.
    def parse_text_block
      result = [:multi]

      interpolate = parse_interpolate_line
      result << interpolate if interpolate

      until @scanner.eos?
        if @scanner.skip(/\r?\n[ \t]*(?=\r?\n)/)
          result << [:newline]
          next
        end

        @scanner.match?(/\r?\n[ \t]*/)
        indent = indent_from_last_match
        break if indent <= @indents.last

        @scanner.pos += @scanner.matched_size
        result << [:newline]
        result << parse_interpolate_line
      end

      result
    end

    # @return [Array, nil] S-expression if found.
    def parse_interpolate_line
      return unless @scanner.match?(/[^\r\n]+/)

      begin_ = @scanner.charpos
      value = @scanner.matched
      @scanner.pos += @scanner.matched_size
      end_ = @scanner.charpos
      [:slimi, :interpolate, begin_, end_, value]
    end

    # @note Broken line means line-breaked lines, separated by trailing "," or "\".
    # @return [String]
    def parse_broken_lines
      result = +''
      result << @scanner.scan(/[^\r\n]*/)
      while result.rstrip.end_with?(',') || result.rstrip.end_with?('\\')
        syntax_error!(Errors::UnexpectedEosError) unless @scanner.scan(/\r?\n/)

        result << "\n"
        result << @scanner.scan(/[^\r\n]*/)
      end
      result
    end

    # Wrap the result s-expression of given block with slimi-position s-expression.
    def with_position(&block)
      begin_ = @scanner.charpos
      inner = block.call
      end_ = @scanner.charpos
      [:slimi, :position, begin_, end_, inner]
    end

    # @param [Class] syntax_error_class A child class of Slimi::Errors::SlimSyntaxError.
    # @raise [Slimi::Errors::SlimSyntaxError]
    def syntax_error!(syntax_error_class)
      range = Range.new(index: @scanner.charpos, source: @scanner.string)
      raise syntax_error_class.new(
        column: range.column,
        file_path: @file_path,
        line: range.line,
        line_number: range.line_number
      )
    end

    # Convert human-friendly options into machine-friendly objects.
    class Factory
      EMBEDDED_TEMPLATE_ENGINE_NAMES = %w[
        coffee
        css
        javascript
        less
        markdown
        rdoc
        ruby
        sass
        scss
        textile
      ].freeze

      # @return [Hash]
      attr_reader :attribute_delimiters

      # @return [Hash]
      attr_reader :ruby_attribute_delimiters

      # @param [Hash] attribute_delimiters
      # @param [String] default_tag
      # @param [Hash] ruby_attribute_delimiters
      # @param [Hash] shortcut
      def initialize(attribute_delimiters:, default_tag:, ruby_attribute_delimiters:, shortcut:)
        @attribute_delimiters = attribute_delimiters
        @default_tag = default_tag
        @ruby_attribute_delimiters = ruby_attribute_delimiters
        @shortcut = shortcut
      end

      # @return [Hash] e.g. `{ "." => { "a" => "b" }}`
      #                        ^^^      ^^^    ^^^
      #                          |        |       `- attribute value
      #                          |         `- attribute key
      #                           `- marker
      def additional_attributes
        @additional_attributes ||= @shortcut.each_with_object({}) do |(marker, details), result|
          result[marker] = details[:additional_attrs] if details.key?(:additional_attrs)
        end
      end

      # @return [Hash] e.g. `{ "." => ["class"] }`
      #                        ^^^     ^^^^^^^
      #                          |            `- attribute name
      #                           `- marker
      def attribute_shortcuts
        @attribute_shortcuts ||= @shortcut.each_with_object({}) do |(marker, details), result|
          result[marker] = Array(details[:attr]) if details.key?(:attr)
        end
      end

      # @return [Hash] e.g. `{ "." => "div" }`
      #                        ^^^    ^^^^^
      #                          |         `- tag name
      #                           `- marker
      def tag_shortcuts
        @tag_shortcuts ||= @shortcut.transform_values do |details|
          details[:tag] || @default_tag
        end
      end

      # @return [Regexp] Pattern that matches to attribute delimiter.
      def attribute_delimiter_regexp
        delimiters_regexp = ::Regexp.union(@attribute_delimiters.keys)
        /[ \t]*(#{delimiters_regexp})/
      end

      # @return [Regexp]
      def attribute_name_regexp
        @attribute_name_regexp ||= begin
          characters = ::Regexp.escape(@attribute_delimiters.flatten.uniq.join)
          %r{[ \t]*([^\0 \t\r\n"'<>/=#{characters}]+)}
        end
      end

      # @return [Regexp] Pattern that matches to attribute shortcuts part.
      def attribute_shortcut_regexp
        markers = attribute_shortcuts.keys.sort_by { |marker| -marker.size }
        markers_regexp = ::Regexp.union(markers)
        %r{(#{markers_regexp}+)((?:\p{Word}|-|/\d+|:(\w|-)+)*)}
      end

      # @return [Regexp]
      def ruby_attribute_regexp
        /#{attribute_name_regexp}[ \t]*=(=?)[ \t]*/
      end

      # @return [Regexp]
      def embedded_template_regexp
        /(#{::Regexp.union(EMBEDDED_TEMPLATE_ENGINE_NAMES)})(?:[ \t]*(?:(.*)))?:([ \t]*)/
      end

      # @return [Regexp]
      def quoted_attribute_regexp
        /#{attribute_name_regexp}[ \t]*=(=?)[ \t]*("|')/
      end

      # @return [Regexp]
      def ruby_attribute_delimiter_regexp
        ::Regexp.union(@ruby_attribute_delimiters.keys)
      end

      # @return [Regexp] Pattern that matches to tag header part.
      def tag_name_regexp
        markers = tag_shortcuts.keys.sort_by { |marker| -marker.size }
        markers_regexp = ::Regexp.union(markers)
        /#{markers_regexp}|\*(?=[^ \t]+)|(\p{Word}(?:\p{Word}|:|-)*\p{Word}|\p{Word}+)/
      end
    end
  end
end
