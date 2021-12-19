# frozen_string_literal: true

require 'temple'

module Slimi
  class RemovePositionFilter < ::Temple::Filter
    # @param [Integer] _begin
    # @param [Integer] _end
    # @return [Array] S-expression. (e.g. `[:slim, :interpolate, "foo"]`)
    def on_slimi_position(_begin, _end, slim)
      slim
    end
  end
end
