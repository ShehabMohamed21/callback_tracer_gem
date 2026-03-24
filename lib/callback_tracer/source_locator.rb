module CallbackTracer
  module SourceLocator
    module_function

    def locate(filter, model_class)
      location = extract_location(filter, model_class)
      return nil unless location

      file, line = location
      shorten_path(file, line)
    end

    def extract_location(filter, model_class)
      case filter
      when Symbol
        if model_class.method_defined?(filter, false) || model_class.private_method_defined?(filter, false)
          model_class.instance_method(filter).source_location
        elsif model_class.method_defined?(filter) || model_class.private_method_defined?(filter)
          model_class.instance_method(filter).source_location
        end
      when Proc
        filter.source_location
      when Object
        # Callable object — try common callback method names
        [:before, :after, :around, :call].each do |m|
          return filter.method(m).source_location if filter.respond_to?(m)
        end
        nil
      end
    rescue NameError, TypeError
      nil
    end

    # Matches bundled gem paths like /gems/activerecord-7.1.0/ or /gems/railties-7.1.0/
    BUNDLED_GEM_PATH_PATTERN = %r{/gems/[a-zA-Z0-9_-]+-\d+}

    def framework_source?(filter, model_class)
      location = extract_location(filter, model_class)
      return false unless location

      file = location[0].to_s
      return true if file.match?(BUNDLED_GEM_PATH_PATTERN)
      return true if defined?(Rails) && Rails.respond_to?(:root) && Rails.root && !file.start_with?(Rails.root.to_s)

      false
    end

    def shorten_path(file, line)
      shortened = if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
                    file.sub("#{Rails.root}/", "")
                  elsif defined?(Bundler) && Bundler.respond_to?(:root)
                    file.sub("#{Bundler.root}/", "")
                  else
                    File.basename(File.dirname(file)) + "/" + File.basename(file)
                  end
      "#{shortened}:#{line}"
    end
  end
end
