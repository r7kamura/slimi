# frozen_string_literal: true

module Slimi
  module Filters
    class Unposition < Base
      # @param [Integer] _begin
      # @param [Integer] _end
      # @param [Array] expression
      # @return [Array]
      def on_slimi_position(_begin, _end, expression)
        compile(expression)
      end
    end
  end
end
