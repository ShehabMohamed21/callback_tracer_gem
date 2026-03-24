require "active_support"
require "active_record"

require_relative "callback_tracer/version"
require_relative "callback_tracer/configuration"
require_relative "callback_tracer/source_locator"
require_relative "callback_tracer/log_formatter"
require_relative "callback_tracer/tracer"
require_relative "callback_tracer/middleware"
require_relative "callback_tracer/railtie" if defined?(Rails::Railtie)

module CallbackTracer
  SETUP_MUTEX = Mutex.new

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def setup!
      SETUP_MUTEX.synchronize do
        return if @setup_done

        if defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?
          warn "[CallbackTracer] WARNING: CallbackTracer.setup! called in production. Tracing is disabled in production by default."
          return
        end

        ActiveRecord::Base.prepend(Tracer)
        @setup_done = true
      end
    end

    def reset!
      SETUP_MUTEX.synchronize do
        @configuration = Configuration.new
        @setup_done = false
      end
    end

    def enabled?
      configuration.enabled
    end

    def buffer
      Thread.current[:callback_tracer_buffer] ||= []
    end

    def buffer_message(message)
      buffer << message
    end

    def clear_buffer!
      Thread.current[:callback_tracer_buffer] = []
    end

    def flush_buffer!
      messages = buffer
      return if messages.empty?

      logger = configuration.logger
      output_logger = logger || Logger.new($stdout, formatter: proc { |_, _, _, msg| "#{msg}\n" })
      messages.each { |msg| output_logger.info(msg) }
    ensure
      clear_buffer!
    end
  end
end
