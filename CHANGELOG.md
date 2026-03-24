# Changelog

## 0.1.0 (2026-03-24)

- Initial release
- Trace all ActiveRecord callback chains (validation, save, create, update, destroy, commit, rollback, initialize, find, touch)
- Source location and timing for each callback
- Around callback enter/exit tracing
- Colorized terminal output
- Configurable: enable/disable, exclude models, custom logger
- Rails generator for initializer setup
- Automatic production safety (disabled in production)
- Rack middleware for per-request buffer flushing
