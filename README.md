# CallbackTracer

Trace ActiveRecord callback execution order with source locations and timing. See exactly which callbacks fire, in what order, and how long each takes.

## Installation

Add to your Gemfile:

```ruby
gem "callback_tracer", group: [:development, :test]
```

Run the install generator:

```bash
rails generate callback_tracer:install
```

## Configuration

```ruby
# config/initializers/callback_tracer.rb
CallbackTracer.configure do |config|
  config.enabled = true
  config.excluded_models = ["ApplicationRecord"]
  config.colorize = true
  config.logger = nil # defaults to puts
end
```

## Output

```
[CallbackTracer] Post before_validation (app/models/post.rb:11) 0.02ms
[CallbackTracer] Post after_validation  (app/models/post.rb:12) 0.01ms
[CallbackTracer] Post before_save       (app/models/post.rb:16) 0.03ms
[CallbackTracer] Post before_create     (app/models/post.rb:21) 0.15ms
[CallbackTracer] Post after_create      (app/models/post.rb:23) 0.02ms
[CallbackTracer] Post after_save        (app/models/post.rb:18) 0.01ms
[CallbackTracer] Post after_commit      (app/models/post.rb:31) 0.04ms
```

## Requirements

- Ruby 3.1+
- Rails 7.0+

Automatically disabled in production.
