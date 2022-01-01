# frozen_string_literal: true

module Slimi
  module Filters
    # Handle `[:slim, :control, code, multi]`.
    class Control < ::Temple::HTML::Filter
      # @param [String] code
      # @param [Array] multi
      # @return [Array]
      def on_slim_control(code, multi)
        [
          :multi,
          [:code, code],
          compile(multi)
        ]
      end
    end
  end
end
