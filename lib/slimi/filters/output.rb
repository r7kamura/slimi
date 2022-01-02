# frozen_string_literal: true

module Slimi
  module Filters
    # Handle `[:slimi, :output, escape, code, multi]`.
    class Output < ::Temple::HTML::Filter
      define_options :disable_capture

      IF_REGEXP = /\A(if|unless)\b|\bdo\s*(\|[^|]*\|)?\s*$/.freeze

      # @param [Boolean] escape
      # @param [String] code
      # @param [Array] multi
      # @return [Array]
      def on_slimi_output(escape, code, multi)
        if code.match?(IF_REGEXP)
          tmp = unique_name
          [
            :multi,
            [:block, "#{tmp} = #{code}", options[:disable_capture] ? compile(multi) : [:capture, unique_name, compile(multi)]],
            [:escape, escape, [:dynamic, tmp]]
          ]
        else
          [
            :multi,
            [:escape, escape, [:dynamic, code]],
            multi
          ]
        end
      end
    end
  end
end
