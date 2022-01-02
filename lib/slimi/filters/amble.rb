# frozen_string_literal: true

module Slimi
  module Filters
    # Support Rails annotate_rendered_view_with_filenames feature.
    class Amble < Base
      define_options(
        :postamble,
        :preamble
      )

      # @param [Array] expression
      # @return [Array]
      def call(expression)
        result = %i[multi]
        result << [:static, options[:preamble]] if options[:preamble]
        result << expression
        result << [:static, options[:postamble]] if options[:postamble]
        result
      end
    end
  end
end
