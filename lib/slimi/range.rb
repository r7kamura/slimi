# frozen_string_literal: true

module Slimi
  # Get line-based information from source code and its index.
  class Range
    # @param [Integer] index 0-indexed per-character index.
    # @param [String] source
    def initialize(index:, source:)
      @index = index
      @source = source
    end

    # @return [Integer] 1-indexed column index.
    def column
      (@index - line_beginning_index) + 1
    end

    def line
      @source[line_beginning_index...line_ending_index]
    end

    # @return [Integer] 1-indexed line index.
    def line_number
      @source[0..@index].scan(/^/).length
    end

    private

    # @return [Integer]
    def line_beginning_index
      @source.rindex(/^/, @index) || 0
    end

    # @return [Integer]
    def line_ending_index
      @source.index(/$/, @index)
    end
  end
end
