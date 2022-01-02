# frozen_string_literal: true

module Slimi
  # Render Slim template in response to requests from Rails.
  class RailsTemplateHandler
    # @param [ActionView::Template] template
    # @param [String, nil] source
    # @return [String]
    def call(template, source = nil)
      Render.new(
        source: source,
        template: template
      ).call
    end

    # Render HTML from given source and options.
    class Renderer
      # @param [String] source
      # @param [ActionView::Template] template
      def initialize(
        source:,
        template:
      )
        @source = source
        @template = template
      end

      # @return [String]
      def call
        engine.call(source)
      end

      private

      # @return [Slimi::Engine]
      def engine
        Engine.new(engine_options)
      end

      # @return [Hash{Symbol => Object}]
      def engine_options
        engine_default_options.merge(engine_amble_options)
      end

      # @return [Hash{Symbol => Object}]
      def engine_default_options
        {
          generator: ::Temple::Generators::RailsOutputBuffer,
          streaming: true,
          use_html_safe: true
        }
      end

      # @return [Hash{Symbol => Object}]
      def engine_amble_options
        if with_annotate_rendered_view_with_filenames?
          {
            postamble: "<!-- END #{template.short_identifier} -->\n",
            preamble: "<!-- BEGIN #{template.short_identifier} -->\n"
          }
        else
          {}
        end
      end

      # @return [String]
      def source
        @source || @template.source
      end

      # @return [Boolean]
      def with_annotate_rendered_view_with_filenames?
        ::ActionView::Base.try(:annotate_rendered_view_with_filenames) && @template.format == :html
      end
    end
  end
end
