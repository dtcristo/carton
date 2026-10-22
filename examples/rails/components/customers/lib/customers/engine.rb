# frozen_string_literal: true

module Customers
  class Engine < Framework::Rails::Engine
    isolate_namespace Customers
    config.root = File.expand_path('../..', __dir__)

    initializer 'customers.carton_loader', before: :set_autoload_paths do
      # Rails still owns routes, views, locales, and migration discovery.
      # Its framework-Box loader must not evaluate this Carton's Ruby files.
      Framework::Rails.autoloaders.main.ignore(
        %w[models controllers repositories].map do |directory|
          root.join('app', directory)
        end,
      )
    end

    initializer 'customers.eager_load',
                after: :load_config_initializers do |app|
      LOADER.eager_load if app.config.eager_load
    end
  end
end
