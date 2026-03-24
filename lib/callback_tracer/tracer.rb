require "logger"
require "monitor"

module CallbackTracer
  module Tracer
    TRACED_KINDS = %i[
      validation save create update destroy
      commit rollback initialize find touch
    ].freeze

    TRACE_MONITOR = Monitor.new

    def run_callbacks(kind, &block)
      unless CallbackTracer.enabled? &&
             TRACED_KINDS.include?(kind) &&
             !CallbackTracer.configuration.excluded?(self.class)
        return super
      end

      callbacks = self.class.__callbacks[kind]
      return super unless callbacks

      chain = callbacks.send(:chain).dup
      colorize = CallbackTracer.configuration.colorize
      model_name = LogFormatter.sanitize(self.class.name.to_s)
      logger = CallbackTracer.configuration.logger

      # Build wrappers for each callback in the chain, skipping framework-internal ones
      wrappers = chain.filter_map do |cb|
        filter = cb.filter
        next if SourceLocator.framework_source?(filter, self.class)

        location = SourceLocator.locate(filter, self.class)
        cb_kind = cb.kind # :before, :after, :around
        method_name = filter.is_a?(Symbol) ? filter : nil

        { callback: cb, filter: filter, location: location, cb_kind: cb_kind, method_name: method_name }
      end

      # Install temporary method wrappers to trace individual callbacks
      install_method_wrappers(wrappers, model_name, kind, colorize, logger)

      # For proc filters, wrap them thread-safely without mutating shared state
      trace_proc_filters(wrappers, model_name, kind, colorize, logger) do
        super(kind, &block)
      end
    end

    private

    def install_method_wrappers(wrappers, model_name, callback_kind, colorize, logger)
      # Track which methods we've already wrapped on this instance to avoid accumulation
      @_callback_tracer_wrapped ||= Set.new

      wrappers.each do |w|
        filter = w[:filter]
        next unless filter.is_a?(Symbol)
        next if @_callback_tracer_wrapped.include?(filter)
        next unless self.class.method_defined?(filter, false) || self.class.private_method_defined?(filter, false)

        location = w[:location]
        cb_kind = w[:cb_kind]
        method_name = w[:method_name]

        wrapper_module = Module.new do
          if cb_kind == :around
            define_method(filter) do |*args, &blk|
              output_enter = LogFormatter.format_around_enter(
                model_name: model_name,
                callback_kind: callback_kind,
                location: location,
                method_name: method_name,
                colorize: colorize
              )
              log_trace(output_enter, logger)

              start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              result = super(*args, &blk)
              duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

              output_exit = LogFormatter.format_around_exit(
                model_name: model_name,
                callback_kind: callback_kind,
                location: location,
                method_name: method_name,
                duration_ms: duration,
                colorize: colorize
              )
              log_trace(output_exit, logger)
              result
            end
          else
            define_method(filter) do |*args, &blk|
              start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              result = super(*args, &blk)
              duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

              output = LogFormatter.format_callback(
                model_name: model_name,
                callback_kind: callback_kind,
                callback_type: cb_kind,
                location: location,
                method_name: method_name,
                duration_ms: duration,
                colorize: colorize
              )
              log_trace(output, logger)
              result
            end
          end
        end

        self.singleton_class.prepend(wrapper_module)
        @_callback_tracer_wrapped.add(filter)
      end
    end

    def trace_proc_filters(wrappers, model_name, callback_kind, colorize, logger)
      proc_wrappers = wrappers.select { |w| w[:filter].is_a?(Proc) }

      if proc_wrappers.empty?
        return yield
      end

      # Thread-safe approach: duplicate the callback objects before mutating,
      # then swap the entire chain under a mutex so no shared state is modified.
      callbacks_set = self.class.__callbacks[callback_kind]
      original_chain = callbacks_set.send(:chain)

      # Deep-copy the callback objects we need to wrap
      cloned_cbs = {}
      proc_wrappers.each do |w|
        cb = w[:callback]
        cloned = cb.dup
        cloned_cbs[cb.object_id] = { original: cb, clone: cloned }
      end

      # Build wrapped procs on the cloned copies (no shared state mutation)
      cloned_cbs.each_value do |entry|
        cloned_cb = entry[:clone]
        w = proc_wrappers.find { |pw| pw[:callback].object_id == entry[:original].object_id }
        filter = w[:filter]
        location = w[:location]
        cb_kind = w[:cb_kind]

        wrapped_proc = build_wrapped_proc(filter, cb_kind, model_name, callback_kind, location, colorize, logger)
        cloned_cb.instance_variable_set(:@filter, wrapped_proc)
      end

      # Hold mutex for the entire swap-yield-restore cycle to prevent
      # TOCTOU race conditions between concurrent threads.
      TRACE_MONITOR.synchronize do
        cloned_cbs.each_value do |entry|
          idx = original_chain.index(entry[:original])
          original_chain[idx] = entry[:clone] if idx
        end

        begin
          yield
        ensure
          cloned_cbs.each_value do |entry|
            idx = original_chain.index(entry[:clone])
            original_chain[idx] = entry[:original] if idx
          end
        end
      end
    end

    def build_wrapped_proc(filter, cb_kind, model_name, callback_kind, location, colorize, logger)
      if cb_kind == :around
        proc do |record, &blk|
          output_enter = LogFormatter.format_around_enter(
            model_name: model_name,
            callback_kind: callback_kind,
            location: location,
            colorize: colorize
          )
          record.send(:log_trace, output_enter, logger)

          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = filter.call(record, &blk)
          duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

          output_exit = LogFormatter.format_around_exit(
            model_name: model_name,
            callback_kind: callback_kind,
            location: location,
            duration_ms: duration,
            colorize: colorize
          )
          record.send(:log_trace, output_exit, logger)
          result
        end
      else
        proc do |record, &blk|
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = record.instance_exec(&filter)
          duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

          output = LogFormatter.format_callback(
            model_name: model_name,
            callback_kind: callback_kind,
            callback_type: cb_kind,
            location: location,
            duration_ms: duration,
            colorize: colorize
          )
          record.send(:log_trace, output, logger)
          result
        end
      end
    end

    def log_trace(message, _logger = nil)
      CallbackTracer.buffer_message(message)
    end
  end
end
