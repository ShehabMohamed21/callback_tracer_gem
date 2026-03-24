require "rails/generators"

module CallbackTracer
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates a CallbackTracer initializer file"

      def create_initializer
        create_file "config/initializers/callback_tracer.rb", <<~RUBY
          CallbackTracer.configure do |config|
            # Enable or disable tracing (automatically disabled in production)
            # config.enabled = true

            # Models to exclude from tracing
            # config.excluded_models = ["ApplicationRecord", "ActiveRecord::SchemaMigration"]

            # Enable colorized output
            # config.colorize = true

            # Custom logger (defaults to puts)
            # config.logger = Rails.logger
          end
        RUBY
      end
    end
  end
end
