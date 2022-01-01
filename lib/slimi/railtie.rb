# frozen_string_literal: true

module Slimi
  class Railtie < ::Rails::Railtie
    initializer 'Register Slimi template handler' do
      ::ActiveSupport.on_load(:action_view) do
        require 'slimi/rails_template_handler'
        ::ActionView::Template.register_template_handler(
          RailsTemplateHandler.new
        )
      end
    end
  end
end
