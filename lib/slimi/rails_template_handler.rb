# frozen_string_literal: true

module Slimi
  class RailsTemplateHandler
    def initialize
      @engine = Engine.new(
        generator: ::Temple::Generators::RailsOutputBuffer,
        streaming: true,
        use_html_safe: true
      )
    end

    def call(template, source = nil)
      source ||= template.source
      @engine.call(source)
    end
  end
end
