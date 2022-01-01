# frozen_string_literal: true

module Slimi
  class RailsTemplateHandler
    def initialize
      @engine = Engine.new
    end

    def call(template, source = nil)
      source ||= template.source
      @engine.call(source)
    end
  end
end
