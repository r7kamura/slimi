# frozen_string_literal: true

require_relative 'slimi/version'

module Slimi
  autoload :Errors, 'slimi/errors'
  autoload :Filters, 'slimi/filters'
  autoload :Parser, 'slimi/parser'
end
