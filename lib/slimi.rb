# frozen_string_literal: true

require_relative 'slimi/version'

module Slimi
  autoload :Engine, 'slimi/engine'
  autoload :Errors, 'slimi/errors'
  autoload :Filters, 'slimi/filters'
  autoload :Parser, 'slimi/parser'
  autoload :RailsTemplateHandler, 'slimi/rails_template_handler'
  autoload :Range, 'slimi/range'
end

require_relative 'slimi/railtie' if defined?(Rails)
