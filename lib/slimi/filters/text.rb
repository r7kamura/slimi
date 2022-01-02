# frozen_string_literal: true

module Slimi
  module Filters
    # Handle `[:slimi, :text, multi]`.
    class Text < ::Temple::HTML::Filter
      # @param [Symbol] _type
      # @param [Array] multi
      # @return [Array]
      def on_slimi_text(_type, multi)
        compile(multi)
      end
    end
  end
end
