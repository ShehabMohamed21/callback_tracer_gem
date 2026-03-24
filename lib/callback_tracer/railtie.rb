module CallbackTracer
  class Railtie < Rails::Railtie
    initializer "callback_tracer.setup" do
      ActiveSupport.on_load(:active_record) do
        CallbackTracer.setup! unless Rails.env.production?
      end
    end

    initializer "callback_tracer.middleware" do |app|
      app.middleware.use CallbackTracer::Middleware unless Rails.env.production?
    end
  end
end
