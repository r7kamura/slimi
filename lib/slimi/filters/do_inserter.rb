# frozen_string_literal: true

module Slimi
  module Filters
    # Append missing `do` to embedded Ruby code.
    class DoInserter < ::Temple::HTML::Filter
      VALID_RUBY_LINE_REGEXP = /(\A(if|unless|else|elsif|when|begin|rescue|ensure|case)\b)|\bdo\s*(\|[^|]*\|\s*)?\Z/.freeze

      # @param [String] code
      # @param [Array] expressio
      # @return [Array]
      def on_slimi_control(code, expression)
        code += ' do' unless code.match?(VALID_RUBY_LINE_REGEXP) || empty_exp?(expression)
        [:slimi, :control, code, compile(expression)]
      end

      # @param [Boolean] escape
      # @param [String] code
      # @param [Array] expression
      # @return [Array]
      def on_slimi_output(escape, code, expression)
        code += ' do' unless code.match?(VALID_RUBY_LINE_REGEXP) || empty_exp?(expression)
        [:slimi, :output, escape, code, compile(expression)]
      end
    end
  end
end
