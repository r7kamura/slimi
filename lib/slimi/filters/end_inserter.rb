# frozen_string_literal: true

module Slimi
  module Filters
    # Append missing `end` line to embedded Ruby code in control block.
    class EndInserter < ::Temple::HTML::Filter
      # @param [Array<Array>] expressions
      def on_multi(*expressions)
        result = [:multi]
        prev_indent = false
        expressions.each do |source|
          expression = Expression.new(source)
          if expression.control?
            raise ::Temple::FilterError, 'Explicit end statements are forbidden.' if expression.end?

            result << code_end if prev_indent && !expression.else?

            prev_indent = expression.if?
          elsif !expression.newline? && prev_indent
            result << code_end
            prev_indent = false
          end

          result << compile(source)
        end

        result << code_end if prev_indent
        result
      end

      private

      # @return [Array]
      def code_end
        [:code, 'end']
      end

      class Expression
        IF_REGEXP = /\A(if|begin|unless|else|elsif|when|rescue|ensure)\b|\bdo\s*(\|[^|]*\|)?\s*$/.freeze

        ELSE_REGEXP = /\A(else|elsif|when|rescue|ensure)\b/.freeze

        END_REGEXP = /\Aend\b/.freeze

        # @param [Array] expression
        def initialize(expression)
          @expression = expression
        end

        # @return [Boolean]
        def control?
          @expression[0] == :slim && @expression[1] == :control
        end

        # @return [Boolean]
        def if?
          @expression[2].match?(IF_REGEXP)
        end

        # @return [Boolean]
        def else?
          @expression[2].match?(ELSE_REGEXP)
        end

        # @return [Boolean]
        def end?
          @expression[2].match?(END_REGEXP)
        end

        # @return [Boolean]
        def newline?
          @expression[0] == :newline
        end
      end
    end
  end
end
