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
    use ::Slim::Splat::Filter
    use Filters::DoInserter
    use ::Slim::EndInserter
    use ::Slim::Controls
    html :AttributeSorter
    html :AttributeMerger
    use ::Slim::CodeAttributes
    use(:AttributeRemover) { ::Temple::HTML::AttributeRemover.new(remove_empty_attrs: options[:merge_attrs].keys) }
    html :Pretty
    filter :Escapable
    filter :ControlFlow
    filter :MultiFlattener
    filter :StaticMerger
    generator :StringBuffer
  end
end
