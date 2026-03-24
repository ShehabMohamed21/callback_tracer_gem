module CallbackTracer
  class Configuration
    attr_reader :enabled, :excluded_models, :colorize, :logger

    def initialize
      @enabled = false
      @excluded_models = []
      @colorize = true
      @logger = nil
    end

    def enabled=(value)
      @enabled = !!value
    end

    def colorize=(value)
      @colorize = !!value
    end

    def excluded_models=(value)
      raise ArgumentError, "excluded_models must be an Array" unless value.is_a?(Array)

      @excluded_models = value
    end

    def logger=(value)
      if value && !value.respond_to?(:info)
        raise ArgumentError, "logger must respond to #info"
      end

      @logger = value
    end

    def excluded?(model_class)
      model_name = model_class.name
      return false unless model_name

      excluded_models.any? do |name|
        model_name == name ||
          model_class.ancestors.any? { |a| a.name == name && name != "ActiveRecord::Base" }
      end
    end
  end
end
