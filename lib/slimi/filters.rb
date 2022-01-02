# frozen_string_literal: true

module Slimi
  module Filters
    autoload :Amble, 'slimi/filters/amble'
    autoload :Attribute, 'slimi/filters/attribute'
    autoload :Base, 'slimi/filters/base'
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
