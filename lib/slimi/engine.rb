# frozen_string_literal: true

require 'slim' # TODO: Eliminate this dependency in the future.
require 'temple'

module Slimi
  # Convert Slim code into Ruby code.
  class Engine < ::Temple::Engine
    define_options(
      attr_quote: '"',
      default_tag: 'div',
      format: :xhtml,
      merge_attrs: { 'class' => ' ' },
      pretty: false,
      sort_attrs: true
    )

    use Parser
    use Filters::Unposition
    use ::Slim::Embedded
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
    filter :Escapable
    filter :ControlFlow
    filter :MultiFlattener
    filter :StaticMerger
    generator :StringBuffer
  end
end
