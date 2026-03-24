module CallbackTracer
  module LogFormatter
    COLORS = {
      prefix:   "\e[36m",   # cyan
      model:    "\e[33m",   # yellow
      callback: "\e[32m",   # green
      location: "\e[90m",   # gray
      timing:   "\e[35m",   # magenta
      around:   "\e[34m",   # blue
      reset:    "\e[0m"
    }.freeze

    # Control characters that could be used for log injection or terminal escape attacks
    CONTROL_CHAR_PATTERN = /[\r\n\e\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/

    module_function

    def sanitize(str)
      str.to_s.gsub(CONTROL_CHAR_PATTERN, "")
    end

    def format_callback(model_name:, callback_kind:, callback_type:, location:, duration_ms:, method_name: nil, colorize: true)
      model_name = sanitize(model_name)
      kind_label = sanitize("#{callback_type}_#{callback_kind}")
      kind_label = "#{kind_label} :#{method_name}" if method_name
      loc_str = location ? "(#{sanitize(location)})" : "(unknown)"
      time_str = "%.2fms" % duration_ms

      if colorize
        "#{c(:prefix)}[CallbackTracer]#{c(:reset)} " \
        "#{c(:model)}#{model_name}#{c(:reset)} " \
        "#{c(:callback)}#{kind_label.ljust(25)}#{c(:reset)} " \
        "#{c(:location)}#{loc_str}#{c(:reset)} " \
        "#{c(:timing)}#{time_str}#{c(:reset)}"
      else
        "[CallbackTracer] #{model_name} #{kind_label.ljust(25)} #{loc_str} #{time_str}"
      end
    end

    def format_around_enter(model_name:, callback_kind:, location:, method_name: nil, colorize: true)
      model_name = sanitize(model_name)
      loc_str = location ? "(#{sanitize(location)})" : "(unknown)"
      label = sanitize("around_#{callback_kind} [enter]")
      label = "#{label} :#{method_name}" if method_name

      if colorize
        "#{c(:prefix)}[CallbackTracer]#{c(:reset)} " \
        "#{c(:model)}#{model_name}#{c(:reset)} " \
        "#{c(:around)}#{label.ljust(25)}#{c(:reset)} " \
        "#{c(:location)}#{loc_str}#{c(:reset)}"
      else
        "[CallbackTracer] #{model_name} #{label.ljust(25)} #{loc_str}"
      end
    end

    def format_around_exit(model_name:, callback_kind:, location:, duration_ms:, method_name: nil, colorize: true)
      model_name = sanitize(model_name)
      loc_str = location ? "(#{sanitize(location)})" : "(unknown)"
      time_str = "%.2fms" % duration_ms
      label = sanitize("around_#{callback_kind} [exit]")
      label = "#{label} :#{method_name}" if method_name

      if colorize
        "#{c(:prefix)}[CallbackTracer]#{c(:reset)} " \
        "#{c(:model)}#{model_name}#{c(:reset)} " \
        "#{c(:around)}#{label.ljust(25)}#{c(:reset)} " \
        "#{c(:location)}#{loc_str}#{c(:reset)} " \
        "#{c(:timing)}#{time_str}#{c(:reset)}"
      else
        "[CallbackTracer] #{model_name} #{label.ljust(25)} #{loc_str} #{time_str}"
      end
    end

    def c(name)
      COLORS[name]
    end
  end
end
