# frozen_string_literal: true

module Slimi
  module Errors
    class BaseError < StandardError
    end

    class SlimSyntaxError < BaseError
      # @param [Integer] column
      # @param [String] file_path
      # @param [String] line
      # @param [Integer] line_number
      def initialize(column:, file_path:, line:, line_number:)
        super()
        @column = column
        @file_path = file_path
        @line = line
        @line_number = line_number
      end

      # @note Override.
      # @return [String]
      def to_s
        <<~TEXT
          #{error_type} at #{@file_path}:#{@line_number}:#{@column}
          #{@line.rstrip}
          #{' ' * (@column - 1)}^
        TEXT
      end

      private

      # @return [String]
      def error_type
        self.class.to_s.split('::').last
      end
    end

    class AttributeClosingDelimiterNotFoundError < SlimSyntaxError
    end

    class InvalidEmptyAttributeError < SlimSyntaxError
    end

    class LineEndingNotFoundError < SlimSyntaxError
    end

    class MalformedIndentationError < SlimSyntaxError
    end

    class RubyAttributeClosingDelimiterNotFoundError < SlimSyntaxError
    end

    class UnexpectedEosError < SlimSyntaxError
    end

    class UnexpectedIndentationError < SlimSyntaxError
    end

    class UnexpectedTextAfterClosedTagError < SlimSyntaxError
    end

    class UnknownLineIndicatorError < SlimSyntaxError
    end
  end
end
