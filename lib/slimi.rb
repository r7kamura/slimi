# frozen_string_literal: true

require_relative 'slimi/version'

module Slimi
  autoload :Errors, 'slimi/errors'
  autoload :Parser, 'slimi/parser'
  autoload :RemovePositionFilter, 'slimi/remove_position_filter'
end
