# frozen_string_literal: true

require 'temple'

module Slimi
  # Convert Slim code into Ruby code.
  class Engine < ::Temple::Engine
    define_options(
      attr_quote: '"',
      default_tag: 'div',
      format: :xhtml,
      generator: ::Temple::Generators::StringBuffer,
      merge_attrs: { 'class' => ' ' },
      pretty: false,
      sort_attrs: true
    )

    use Parser
    use Filters::Unposition
    use Filters::Embedded
    use Filters::Interpolation
    use Filters::DoInserter
    use Filters::EndInserter
    use Filters::Control
    use Filters::Output
    use Filters::Text
    html :AttributeSorter
    html :AttributeMerger
    use Filters::Attribute
    use(:AttributeRemover) { ::Temple::HTML::AttributeRemover.new(remove_empty_attrs: options[:merge_attrs].keys) }
    html :Pretty
    use Filters::Amble
    filter :Escapable
    filter :ControlFlow
    filter :MultiFlattener
    filter :StaticMerger
    use(:Generator) { options[:generator] }
  end
end
