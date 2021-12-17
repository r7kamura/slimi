# frozen_string_literal: true

require 'strscan'

module Slimi
  class Parser
    def initialize(*); end

    def call(source)
      @stacks = [[:multi]]
      @indents = []
      @scanner = ::StringScanner.new(source)
      scan_block until @scanner.eos?
      @stacks[0]
    end

    private

    def scan_block
      handle_indent(scan_indent)

      scan_line_ending ||
        scan_tag ||
        scan_html_comment ||
        scan_html_conditional_comment ||
        scan_slim_comment_block ||
        scan_verbatim_text_block ||
        scan_inline_html ||
        scan_code_block ||
        raise('Syntax error.')
    end

    # @return [Boolean]
    def scan_tag
      scan_tag_inner && expect_line_ending
    end

    # @todo Support shortcut attributes (e.g. div.foo).
    # @return [Boolean]
    def scan_tag_inner
      tag_name = @scanner.scan(/\p{Word}+/)
      if tag_name
        attributes = %i[html attrs]
        value = @scanner.scan(/[<>']*/)
        with_trailing_white_space = value.include?('<') || value.include?("'")
        with_leading_white_space = value.include?('>')
        tag = [:html, :tag, tag_name, attributes]
        @stacks.last << [:static, ' '] if with_leading_white_space
        @stacks.last << tag
        @stacks.last << [:static, ' '] if with_trailing_white_space

        if @scanner.skip(/[ \t]*$/)
          content = [:multi]
          tag << content
          @stacks << content
        elsif @scanner.skip(/[ \t]*=(=?)(['<>])*/)
          escaping = !@scanner[1]
          with_trailing_white_space2 = !with_trailing_white_space && @scanner[2] && (@scanner[2].include?('<') || @scanner[2].include?("'"))
          with_leading_white_space2 = !with_leading_white_space && @scanner[2] && @scanner[2].include?('>')
          block = [:multi]
          @stacks.last.insert(-2, [:static, ' ']) if with_leading_white_space2
          tag << [:slim, :output, !escaping, parse_broken_lines, block]
          @stacks.last << [:static, ' '] if with_trailing_white_space2
          @stacks << block
        elsif @scanner.skip(%r{[ \t]*/[ \t]*})
          raise 'Unexpected text after closed tag' unless @scanner.match?(/\r?\n/)
        else
          tag << [:slim, :text, :inline, parse_text_block]
        end
        true
      else
        false
      end
    end

    # @return [Boolean]
    def scan_html_comment
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
    def scan_html_conditional_comment
      scan_html_conditional_comment_inner && expect_line_ending
    end

    # @return [Boolean]
    def scan_html_conditional_comment_inner
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
    def scan_slim_comment_block
      if @scanner.skip(%r{/.*})
        while !@scanner.eos? && (@scanner.match?(/[ \t]*$/) || peek_indent > @indents.last)
          @scanner.skip(/.*/)
          scan_line_ending
        end
        true
      else
        false
      end
    end

    # @return [Boolean]
    def scan_verbatim_text_block
      scan_verbatim_text_block_inner && expect_line_ending
    end

    # @return [Boolean]
    def scan_verbatim_text_block_inner
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
    def scan_inline_html
      scan_inline_html_inner && expect_line_ending
    end

    # @return [Boolean]
    def scan_inline_html_inner
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
    def scan_code_block
      scan_code_block_inner && expect_line_ending
    end

    # @return [Boolean]
    def scan_code_block_inner
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
    def expecting_indentation?
      @stacks.length > @indents.length
    end

    # @param [Integer] indent
    def handle_indent(indent)
      @indents << indent if @indents.empty?

      if indent > @indents.last
        raise 'Unexpected indentation' unless expecting_indentation?

        @indents << indent
      else
        @stacks.pop if expecting_indentation?

        while indent < @indents.last && @indents.length > 1
          @indents.pop
          @stacks.pop
        end

        raise 'Malformed indentation' if indent != @indents.last
      end
    end

    # @raise
    def expect_line_ending
      scan_line_ending || @scanner.eos? || raise('Expect line ending, but other character found')
    end

    # @return [Integer] Indent level.
    def scan_indent
      @scanner.skip(/[ \t]*/)
      indent_from_last_match
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
    def scan_line_ending
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
        raise 'Unexpected EOS' unless @scanner.scan(/\r?\n/)

        result << "\n"
        result << @scanner.scan(/.*/)
      end
      result
    end
  end
end
