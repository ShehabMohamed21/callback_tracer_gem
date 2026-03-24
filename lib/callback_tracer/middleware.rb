module CallbackTracer
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      CallbackTracer.clear_buffer!
      response = @app.call(env)
      response
    ensure
      CallbackTracer.flush_buffer!
    end
  end
end
