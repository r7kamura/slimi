# frozen_string_literal: true

module Slimi
  module Filters
    class Splat < Base
      define_options :attr_quote, :format, :merge_attrs, :sort_attrs, use_html_safe: ''.respond_to?(:html_safe?)

      # @param [Array] exp
      # @return [Array]
      def call(exp)
        @splat_options = nil
        exp = compile(exp)
        if @splat_options
          [:multi, [:code, "#{@splat_options} = #{splat_builder_options.inspect}"], exp]
        else
          exp
        end
      end

      # @param [Array<Array>] attrs
      # @return [Array]
      def on_html_attrs(*attrs)
        return super unless attrs.any? { |attr| splat?(attr) }

        @splat_options ||= unique_name
        builder = unique_name
        result = [:multi]
        result << [:code, "#{builder} = ::#{Builder.name}.new(#{@splat_options})"]
        attrs.each do |attr|
          result << compile_attribute(builder, attr)
        end
        result << [:dynamic, "#{builder}.to_s"]
      end

      private

      # @param [String] builder
      # @param [Array] attr
      # @return [Array]
      def compile_attribute(builder, attr)
        return [:code, "#{builder}.splat((#{attr[2]}))"] if splat?(attr)

        _, _, name, value = attr
        if value[0] == :slimi && value[1] == :attrvalue
          # Pass the raw expression and escape flag through, so that the Builder can
          # apply the same merge / boolean / nil / escape rules as Filters::Attribute.
          [:code, "#{builder}.code_attribute(#{name.to_s.inspect}, #{value[2]}, (#{value[3]}))"]
        elsif value == [:multi]
          # Boolean attribute, e.g. `div(*foo disabled)`.
          [:code, "#{builder}.code_attribute(#{name.to_s.inspect}, false, true)"]
        else
          # Static or interpolated value whose escaping is compiled into the capture,
          # so the Builder must not escape it again.
          tmp = unique_name
          [:multi,
           [:capture, tmp, compile(value)],
           [:code, "#{builder}.attribute(#{name.to_s.inspect}, #{tmp})"]]
        end
      end

      # @param [Array] attr
      # @return [Boolean]
      def splat?(attr)
        attr[0] == :slimi && attr[1] == :splat
      end

      # @return [Hash]
      def splat_builder_options
        {
          attr_quote: options[:attr_quote],
          format: options[:format],
          merge_attrs: options[:merge_attrs],
          sort_attrs: options[:sort_attrs],
          use_html_safe: options[:use_html_safe]
        }
      end

      class Builder
        # https://html.spec.whatwg.org/multipage/syntax.html#attributes-2
        INVALID_ATTRIBUTE_NAME_REGEXP = %r{[ \0"'>/=]}

        # @param [Hash] options
        def initialize(options)
          @attr_quote = options[:attr_quote]
          @format = options[:format]
          @merge_attrs = options[:merge_attrs] || {}
          @sort_attrs = options.fetch(:sort_attrs, true)
          @use_html_safe = options[:use_html_safe]
          @attributes = {}
        end

        # Add an attribute value already rendered and escaped by the compiled template.
        # @param [String] name
        # @param [String] value
        def attribute(name, value)
          store(name, value)
        end

        # Add an attribute value, applying merge / boolean / nil / escape rules.
        # @param [String] name
        # @param [Boolean] escape
        # @param [Object] value
        def code_attribute(name, escape, value)
          if (delimiter = @merge_attrs[name])
            value = value.is_a?(::Array) ? value.flatten.map(&:to_s).reject(&:empty?).join(delimiter) : value.to_s
            store(name, escape_html(escape, value)) unless value.empty?
          elsif value.is_a?(::Hash)
            value.each do |key, nested_value|
              code_attribute("#{name}-#{key}", escape, nested_value)
            end
          elsif value != false && !value.nil?
            store(name, value == true ? true : escape_html(escape, value.to_s))
          end
        end

        # @param [Hash] hash
        def splat(hash)
          hash.each do |name, value|
            code_attribute(name.to_s, true, value)
          end
        end

        # @return [String]
        def to_s
          attributes = @sort_attrs ? @attributes.sort_by(&:first) : @attributes
          attributes.map { |name, value| render(name, value) }.join
        end

        private

        # @param [String] name
        # @param [String, true] value
        def store(name, value)
          raise Errors::InvalidAttributeNameError, "Invalid attribute name '#{name}' was rendered" if INVALID_ATTRIBUTE_NAME_REGEXP.match?(name)

          if @attributes.key?(name)
            delimiter = @merge_attrs[name]
            raise Errors::MultipleAttributesError, "Multiple #{name} attributes specified" unless delimiter

            @attributes[name] = "#{@attributes[name]}#{delimiter}#{value}"
          else
            @attributes[name] = value
          end
        end

        # @param [String] name
        # @param [String, true] value
        # @return [String]
        def render(name, value)
          if value == true
            if @format == :xhtml
              " #{name}=#{@attr_quote}#{@attr_quote}"
            else
              " #{name}"
            end
          else
            " #{name}=#{@attr_quote}#{value}#{@attr_quote}"
          end
        end

        # @param [Boolean] escape
        # @param [String] string
        # @return [String]
        def escape_html(escape, string)
          return string unless escape

          if @use_html_safe
            ::Temple::Utils.escape_html_safe(string)
          else
            ::Temple::Utils.escape_html(string)
          end
        end
      end
    end
  end
end
