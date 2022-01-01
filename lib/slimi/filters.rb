# frozen_string_literal: true

module Slimi
  module Filters
    autoload :Attribute, 'slimi/filters/attribute'
    autoload :Control, 'slimi/filters/control'
    autoload :DoInserter, 'slimi/filters/do_inserter'
    autoload :Embedded, 'slimi/filters/embedded'
    autoload :EndInserter, 'slimi/filters/end_inserter'
    autoload :Interpolation, 'slimi/filters/interpolation'
    autoload :Output, 'slimi/filters/output'
    autoload :Text, 'slimi/filters/text'
    autoload :Unposition, 'slimi/filters/unposition'
  end
end
