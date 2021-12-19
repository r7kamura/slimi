# frozen_string_literal: true

require 'strscan'
require 'temple'

module Slimi
  class Parser < ::Temple::Parser
    define_options(
      attr_list_delims: {
        '(' => ')',
        '[' => ']',
        '{' => '}'
      },
      shortcut: {
        '#' => { attr: 'id' },
        '.' => { attr: 'class' }
      }
    )

    def initialize(options = {})
      super
      factory = Factory.new(
        attribute_delimiters: options[:attr_list_delims] || {},
        default_tag: options[:default_tag] || 'div',
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
      parse_indent

      parse_line_ending ||
        parse_html_comment ||
        parse_html_conditional_comment ||
        parse_slim_comment_block ||
        parse_verbatim_text_block ||
        parse_inline_html ||
        parse_code_block ||
        parse_output_block ||
        parse_doctype ||
        parse_tag ||
        raise(Errors::UnknownLineIndicatorError)
    end

    def parse_indent
      @scanner.skip(/[ \t]*/)
      indent = indent_from_last_match
      @indents << indent if @indents.empty?

      if indent > @indents.last
        raise Errors::UnexpectedIndentationError unless expecting_indentation?

        @indents << indent
      else
        @stacks.pop if expecting_indentation?

        while indent < @indents.last && @indents.length > 1
          @indents.pop
          @stacks.pop
        end

        raise Errors::MalformedIndentationError if indent != @indents.last
      end
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

        if @scanner.skip(/[ \t]*$/)
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
          tag << with_position { [:slim, :output, escape, parse_broken_lines, block] }
          @stacks.last << [:static, ' '] if with_trailing_white_space2
          @stacks << block
        elsif @scanner.skip(%r{[ \t]*/[ \t]*})
          raise Errors::UnexpectedTextAfterClosedTagError unless @scanner.match?(/\r?\n/)
        else
          @scanner.skip(/[ \t]+/)
          tag << [:slim, :text, :inline, parse_text_block]
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
        raise 'Illegal shortcut' unless attribute_names

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
        if @scanner.match?(/#{quote}/) && count.zero?
          end_ = @scanner.charpos
          @scanner.pos += @scanner.matched_size
          break
        end

        if @scanner.skip(/\{/)
          count += 1
        elsif @scanner.skip(/\}/)
          count -= 1
        end
        value << @scanner.scan(/[^{}#{quote}]*/)
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
        boolean_attribute_regexp = /#{@attribute_name_regexp}(?=(?:[ \t]|#{attribute_delimiter_closing_regexp}|$))/
        attribute_delimiter_closing_part_regexp = /[ \t]*#{attribute_delimiter_closing_regexp}/
      end

      loop do
        if @scanner.skip(@quoted_attribute_regexp)
          attribute_name = @scanner[1]
          escape = @scanner[2].empty?
          quote = @scanner[3]
          attributes << [:html, :attr, attribute_name, [:escape, escape, parse_quoted_attribute_value(quote)]]
        elsif !attribute_delimiter_closing_part_regexp
          break
        elsif @scanner.skip(boolean_attribute_regexp)
          attributes << [:html, :attr, @scanner[1], [:multi]]
        elsif @scanner.skip(attribute_delimiter_closing_part_regexp) # rubocop:disable Lint/DuplicateBranch
          break
        else
          raise ::NotImplementedError
        end
      end

      attributes
    end

    # @return [Boolean]
    def parse_html_comment
      if @scanner.skip(%r{/!})
        text_block = parse_text_block
        text = [:slim, :text, :verbatim, text_block]
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
      if @scanner.skip(%r{/.*})
        while !@scanner.eos? && (@scanner.match?(/[ \t]*$/) || peek_indent > @indents.last)
          @scanner.skip(/.*/)
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
        @stacks.last << [:slim, :text, :verbatim, parse_text_block]
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
      if @scanner.match?(/<.*/)
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
        @stacks.last << with_position { [:slim, :control, parse_broken_lines, block] }
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
        @stacks.last << with_position { [:slim, :output, escape, parse_broken_lines, block] }
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
      parse_line_ending || @scanner.eos? || raise(LineEndingNotFoundError)
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
      end.sum(0)
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

      loop do
        break unless @scanner.match?(/\r?\n[ \t]*/)

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
      return unless @scanner.match?(/.+/)

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
      result << @scanner.scan(/.*/)
      while result.end_with?(',') || result.end_with?('\\')
        raise Errors::UnexpectedEosError unless @scanner.scan(/\r?\n/)

        result << "\n"
        result << @scanner.scan(/.*/)
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

    # Convert human-friendly options into machine-friendly objects.
    class Factory
      # @return [Hash]
      attr_reader :attribute_delimiters

      # @param [Hash] attribute_delimiters
      # @param [String] default_tag
      # @param [Hash] shortcut
      def initialize(attribute_delimiters:, default_tag:, shortcut:)
        @attribute_delimiters = attribute_delimiters
        @default_tag = default_tag
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
      def quoted_attribute_regexp
        /#{attribute_name_regexp}[ \t]*=(=?)[ \t]*("|')/
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
