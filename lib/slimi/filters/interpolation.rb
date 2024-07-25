# frozen_string_literal: true

require 'strscan'

module Slimi
  module Filters
    class Interpolation < Base
      # @param [Integer] begin_
      # @param [Integer] end_
      # @return [Array] S-expression.
      def on_slimi_interpolate(begin_, _end_, string)
        block = [:multi]
        scanner = ::StringScanner.new(string)
        until scanner.eos?
          charpos = scanner.charpos
          if (value = scanner.scan("\\\#{"))
            block << [:static, value]
          elsif scanner.scan(/#\{((?>[^{}]|(\{(?>[^{}]|\g<1>)*\}))*)\}/)
            code = scanner[1]
            begin2 = begin_ + charpos + 2
            if code.start_with?('{') && code.end_with?('}')
              escape = true
              code = code[1..-2]
              begin2 -= 1
            else
              escape = false
            end
            block << [:slimi, :position, begin2, begin2 + code.length, [:slimi, :output, escape, code, [:multi]]]
          elsif (value = scanner.scan(/([#\\]?[^#\\]*([#\\][^\\\#{][^#\\]*)*)/)) # rubocop:disable Lint/DuplicateBranch
            block << [:static, value]
          end
        end
        block
      end
    end
  end
end
