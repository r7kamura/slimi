# frozen_string_literal: true

require 'strscan'
require 'temple'

module Slimi
  module Filters
    class Interpolation < ::Temple::Filter
      # @param [Integer] begin_
      # @param [Integer] end_
      # @return [Array] S-expression.
      def on_slimi_interpolate(begin_, end_, string)
        block = [:multi]
        scanner = ::StringScanner.new(string)
        until scanner.eos?
          charpos = scanner.charpos
          if (value = scanner.scan(/\\#\{/) || scanner.scan(/([#\\]?[^#\\]*([#\\][^\\\#{][^#\\]*)*)/))
            block << [:static, value]
          elsif scanner.scan(/#\{((?>[^{}]|(\{(?>[^{}]|\g<1>)*\}))*)\}/)
            code = scanner[1]
            begin2 = begin_ + charpos + 2
            end2 = end_ + scanner.charpos - 1
            if code.start_with?('{') && code.end_with?('}')
              escape = true
              code = code[1..-2]
              begin2 -= 1
              end2 -= 1
            else
              escape = false
            end
            block << [:slimi, :position, begin2, end2, [:slim, :output, escape, code, [:multi]]]
          end
        end
        block
      end
    end
  end
end
