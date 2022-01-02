# frozen_string_literal: true

module Slimi
  module Filters
    # Handle `[:slimi, :attributes, ...]`.
    class Attribute < ::Temple::HTML::Filter
      define_options :merge_attrs

      # @param [Array<Array>] expressions
      # @return [Array]
      def on_html_attrs(*expressions)
        [:multi, *expressions.map { |expression| compile(expression) }]
      end

      # @param [String] name
      # @param [Array] value
      # @return [Array]
      def on_html_attr(name, value)
        if value[0] == :slimi && value[1] == :attrvalue && !options[:merge_attrs][name]
          escape = value[2]
          code = value[3]
          case code
          when 'true'
            [:html, :attr, name, [:multi]]
          when 'false', 'nil'
            [:multi]
          else
            tmp = unique_name
            [:multi,
             [:code, "#{tmp} = #{code}"],
             [:if, tmp,
              [:if, "#{tmp} == true",
               [:html, :attr, name, [:multi]],
               [:html, :attr, name, [:escape, escape, [:dynamic, tmp]]]]]]
          end
        else
          @attr = name
          super
        end
      end

      # @param [Boolean] escape
      # @param [String] code\
      # @return [Array]\
      def on_slimi_attrvalue(escape, code)
        if (delimiter = options[:merge_attrs][@attr])
          tmp = unique_name
          [:multi,
           [:code, "#{tmp} = #{code}"],
           [:if, "Array === #{tmp}",
            [:multi,
             [:code, "#{tmp} = #{tmp}.flatten"],
             [:code, "#{tmp}.map!(&:to_s)"],
             [:code, "#{tmp}.reject!(&:empty?)"],
             [:escape, escape, [:dynamic, "#{tmp}.join(#{delimiter.inspect})"]]],
            [:escape, escape, [:dynamic, tmp]]]]
        else
          [:escape, escape, [:dynamic, code]]
        end
      end
    end
  end
end
