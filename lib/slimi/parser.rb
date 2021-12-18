# frozen_string_literal: true

require 'strscan'
require 'temple'

module Slimi
  class Parser < ::Temple::Parser
    define_options(
      shortcut: {
        '#' => { attr: 'id' },
        '.' => { attr: 'class' }
      }
    )

    def initialize(options = {})
      super
      factory = Factory.new(
        default_tag: options[:default_tag] || 'div',
        shortcut: options[:shortcut] || {}
      )
      @attribute_shortcuts = factory.attribute_shortcuts
      @tag_shortcuts = factory.tag_shortcuts
      @attribute_shortcut_regexp = factory.attribute_shortcut_regexp
      @tag_name_regexp = factory.tag_name_regexp
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

    # @todo Support shortcut attributes (e.g. div.foo).
    # @return [Boolean]
    def parse_tag_inner
      tag_name = parse_tag_name
      if tag_name
        # Parse attribute shortcuts part.
        # e.g. div#foo.bar
        #         ^^^^^^^^
        #                 `- attribute shortcut part
        attributes = %i[html attrs]
        while @scanner.skip(@attribute_shortcut_regexp)
          marker = @scanner[1]
          attribute_value = @scanner[2]
          attribute_names = @attribute_shortcuts[marker]
          raise 'Illegal shortcut' unless attribute_names

          attribute_names.each do |attribute_name|
            attributes << [:html, :attr, attribute_name.to_s, [:static, attribute_value]]
          end
        end

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
          tag << [:slim, :output, escape, parse_broken_lines, block]
          @stacks.last << [:static, ' '] if with_trailing_white_space2
          @stacks << block
        elsif @scanner.skip(%r{[ \t]*/[ \t]*})
          raise Errors::UnexpectedTextAfterClosedTagError unless @scanner.match?(/\r?\n/)
        else
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
      value = @scanner.scan(/<.*/)
      if value
        block = [:multi]
        @stacks.last << [:multi, [:slim, :interpolate, value], block]
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
        @stacks.last << [:slim, :control, parse_broken_lines, block]
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
        @stacks.last << [:slim, :output, escape, parse_broken_lines, block]
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
      value = @scanner.scan(/.+/)
      result << [:slim, :interpolate, value] if value

      loop do
        break unless @scanner.match?(/\r?\n[ \t]*/)

        indent = indent_from_last_match
        break if indent <= @indents.last

        @scanner.pos += @scanner.matched_size
        result << [:newline]
        result << [:slim, :interpolate, @scanner.scan(/.*/)]
      end

      result
    end

    # @note Broken line means line-breaked lines, separated by trailing "," or "\".
    # @return [String]
    def parse_broken_lines
      result = +''
      @scanner.skip(/[ \t]+/)
      result << @scanner.scan(/.*/)
      while result.end_with?(',') || result.end_with?('\\')
        raise Errors::UnexpectedEosError unless @scanner.scan(/\r?\n/)

        result << "\n"
        result << @scanner.scan(/.*/)
      end
      result
    end

    class Factory
      # @param [String] default_tag
      # @param [Hash] shortcut
      def initialize(default_tag:, shortcut:)
        @default_tag = default_tag
        @shortcut = shortcut
      end

      # @return [Hash] e.g. `{ "." => { "a" => "b" }}`
      def additional_attributes
        @additional_attributes ||= @shortcut.each_with_object({}) do |(marker, details), result|
          result[marker] = details[:additional_attrs] if details.key?(:additional_attrs)
        end
      end

      # @return [Hash] e.g. `{ "." => ["class"] }`
      #                         ^^^     ^^^^^^^
      #                           |            `- attribute name
      #                            `- marker
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

      # @return [Regexp] Pattern that matches to attribute shortcuts part.
      def attribute_shortcut_regexp
        markers = attribute_shortcuts.keys.sort_by { |marker| -marker.size }
        markers_regexp = ::Regexp.union(markers)
        %r{(#{markers_regexp}+)((?:\p{Word}|-|/\d+|:(\w|-)+)*)}
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
