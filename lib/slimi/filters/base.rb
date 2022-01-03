# frozen_string_literal: true

require 'temple'

module Slimi
  module Filters
    # Pass-through some expressions which are unknown for Temple.
    class Base < ::Temple::HTML::Filter
      # @param [String] code
      # @param [Array] expression
      # @return [Array]
      def on_slimi_control(code, expression)
        [:slimi, :control, code, compile(expression)]
      end

      # @param [String] type
      # @param [String] code
      # @param [Array] expression
      # @param [Array] attributes
      # @return [Array]
      def on_slimi_embedded(type, expression, attributes)
        [:slimi, :embedded, type, compile(expression), attributes]
      end

      # @param [Boolean] escape
      # @param [String] code
      # @param [Array] expression
      # @return [Array]
      def on_slimi_output(escape, code, expression)
        [:slimi, :output, escape, code, compile(expression)]
      end

      # @param [Integer] begin_
      # @param [Integer] end_
      # @param [Array] expression
      # @return [Array]
      def on_slimi_position(begin_, end_, expression)
        [:slimi, :position, begin_, end_, compile(expression)]
      end

      # @param [String] type
      # @param [Array] expression
      # @return [Array]
      def on_slimi_text(type, expression)
        [:slimi, :text, type, compile(expression)]
      end
    end
  end
end
