# frozen_string_literal: true

module Slimi
  class RemovePositionFilter
    def initialize(*); end

    # @param [Array] node S-expression.
    # @return [Array] S-expression.
    def call(node)
      convert(node)
    end

    private

    def convert(value)
      if value.instance_of?(::Array)
        if value[0] == :slimi && value[1] == :position
          call(value[4])
        else
          value.map do |element|
            call(element)
          end
        end
      else
        value
      end
    end

    # @param [Integer] _begin
    # @param [Integer] _end
    # @return [Array] S-expression. (e.g. `[:slim, :interpolate, "foo"]`)
    def on_slimi_position(_begin, _end, slim)
      slim
    end
  end
end
