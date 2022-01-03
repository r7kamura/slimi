# frozen_string_literal: true

require 'thor'

module Slimi
  # Provide CLI features.
  class Cli < ::Thor
    desc 'compile', 'Convert Slim into Ruby'
    def compile
      slim = $stdin.read
      ruby = Engine.new.call(slim)
      puts ruby
    end

    desc 'erb', 'Convert Slim into ERB'
    def erb
      slim = $stdin.read
      expression = ErbConverter.new.call(slim)
      puts expression
    end

    desc 'parse', 'Convert Slim into Temple expression'
    def parse
      slim = $stdin.read
      expression = Parser.new.call(slim)
      pp expression
    end

    desc 'render', 'Convert Slim into HTML'
    def render
      slim = $stdin.read
      ruby = Engine.new.call(slim)
      result = eval(ruby)
      puts result
    end
  end
end
