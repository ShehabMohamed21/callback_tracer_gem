# CallbackTracer — Complete Guide

## What is CallbackTracer?

CallbackTracer is a development/test gem that instruments your Rails ActiveRecord models and prints every callback as it fires — showing you the exact execution order, source file and line number, and how long each callback took.

Rails callback execution is notoriously hard to follow. Callbacks nest (`save` wraps `create`/`update`), `around` callbacks form onion layers, transaction callbacks defer until commit, and nested attributes interleave parent and child callbacks. None of this is visible at runtime without manual `puts` debugging.

CallbackTracer makes it visible automatically. Add the gem, and every callback across every model shows up in your terminal with zero code changes to your app.

### What it traces

All standard ActiveRecord callback chains:

| Chain          | Callbacks traced                                          |
|----------------|-----------------------------------------------------------|
| **validation** | `before_validation`, `after_validation`                   |
| **save**       | `before_save`, `around_save`, `after_save`                |
| **create**     | `before_create`, `around_create`, `after_create`          |
| **update**     | `before_update`, `around_update`, `after_update`          |
| **destroy**    | `before_destroy`, `around_destroy`, `after_destroy`       |
| **commit**     | `after_commit`, `after_create_commit`, `after_update_commit`, `after_save_commit`, `after_destroy_commit` |
| **rollback**   | `after_rollback`                                          |
| **initialize** | `after_initialize`                                        |
| **find**       | `after_find`                                              |
| **touch**      | `after_touch`                                             |

### What each trace line shows

```
[CallbackTracer] Post before_save (app/models/post.rb:16) 0.03ms
│                │    │            │                        │
│                │    │            │                        └─ execution time
│                │    │            └─ source file and line number
│                │    └─ callback type and chain
│                └─ model name
└─ prefix
```

For `around` callbacks, you get two lines — one when entering the callback and one when exiting — so you can see what happened inside the yield:

```
[CallbackTracer] Post around_save [enter] (app/models/post.rb:47)
[CallbackTracer] Post around_save [exit]  (app/models/post.rb:47) 10.37ms
```

### What it does NOT do

- It does **not** modify your callbacks, models, or database in any way.
- It does **not** run in production. The Railtie automatically skips setup when `Rails.env.production?` is true.
- It does **not** persist any data. All output goes to `$stdout` (or a logger you configure).

---

## Requirements

- **Ruby** >= 3.1.0
- **Rails** >= 7.0 (ActiveRecord, ActiveSupport, Railties)

---

## Installation

### Step 1: Add the gem to your Gemfile

Add it to the `:development` and `:test` groups so it never loads in production:

```ruby
group :development, :test do
  gem "callback_tracer", path: "/path/to/callback_tracer"
end
```

If you keep the gem directory next to your Rails project:

```ruby
gem "callback_tracer", path: "../callback_tracer"
```

### Step 2: Bundle install

```bash
bundle install
```

### Step 3 (optional): Run the install generator

This creates a config initializer at `config/initializers/callback_tracer.rb` with commented-out defaults:

```bash
rails generate callback_tracer:install
```

The generated file looks like this:

```ruby
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
```

**That's it.** No other setup is needed. The gem auto-activates via a Rails Railtie when ActiveRecord loads.

---

## Configuration Options

All configuration is optional. The gem works with zero configuration out of the box.

### `enabled` (default: `true`)

Master switch. Set to `false` to silence all tracing without removing the gem.

```ruby
CallbackTracer.configure do |config|
  config.enabled = false
end
```

### `excluded_models` (default: `[]`)

Array of model class names (as strings) to skip. Useful for silencing noisy internal models.

```ruby
CallbackTracer.configure do |config|
  config.excluded_models = [
    "ApplicationRecord",
    "ActiveRecord::SchemaMigration",
    "ActiveRecord::InternalMetadata",
    "ActionText::RichText"
  ]
end
```

Exclusion also applies to subclasses. If you exclude `"ApplicationRecord"`, all models inheriting from it are silenced.

### `colorize` (default: `true`)

Terminal color output using ANSI escape codes. The color scheme:

| Element      | Color   |
|--------------|---------|
| `[CallbackTracer]` prefix | Cyan    |
| Model name   | Yellow  |
| Callback name| Green   |
| `around` callbacks | Blue |
| Source location | Gray  |
| Timing       | Magenta |

Set to `false` if your terminal doesn't support colors or if you're piping output to a file:

```ruby
config.colorize = false
```

### `logger` (default: `nil` — uses `puts`)

By default, traces go to `$stdout` via `puts`. You can redirect to any Logger-compatible object:

```ruby
# Send to the Rails log file instead of the terminal
config.logger = Rails.logger

# Send to a dedicated file
config.logger = Logger.new("log/callbacks.log")

# Send to a StringIO for programmatic capture
buffer = StringIO.new
config.logger = Logger.new(buffer)
```

---

## Usage

### Basic: just run your app

Once installed, every ActiveRecord operation that fires callbacks will produce trace output. Run any of these and watch your terminal:

```bash
# Rails console
rails console
> Post.create!(title: "Hello", content: "World")

# Rake tasks
rake db:seed

# Tests
bundle exec rspec

# Development server (traces appear as you interact with the app)
rails server
```

### Reading the output

Here is what a basic `Post.create!` produces:

```
[CallbackTracer] Post before_validation    (app/models/post.rb:11)  0.01ms
[CallbackTracer] Post after_validation     (app/models/post.rb:12)  0.01ms
[CallbackTracer] Post before_save          (app/models/post.rb:16)  0.00ms
[CallbackTracer] Post around_save [enter]  (app/models/post.rb:47)
[CallbackTracer] Post before_create        (app/models/post.rb:21)  0.00ms
[CallbackTracer] Post around_create [enter](app/models/post.rb:53)
[CallbackTracer] Post around_create [exit] (app/models/post.rb:53)  10.04ms
[CallbackTracer] Post after_create         (app/models/post.rb:23)  0.00ms
[CallbackTracer] Post around_save [exit]   (app/models/post.rb:47)  10.37ms
[CallbackTracer] Post after_save           (app/models/post.rb:18)  0.00ms
[CallbackTracer] Post after_commit         (app/models/post.rb:31)  0.00ms
[CallbackTracer] Post after_create_commit  (app/models/post.rb:32)  0.00ms
[CallbackTracer] Post after_save_commit    (app/models/post.rb:34)  0.00ms
```

Things to notice:

1. **Execution order is exact.** `before_save` fires before `before_create`. `after_create` fires before `after_save`. This is the real Rails callback order.
2. **`around` callbacks wrap.** `around_save [enter]` appears, then everything inside it (the create chain), then `around_save [exit]` with the total time spent inside the yield.
3. **Commit callbacks fire last.** After the transaction commits, `after_commit` / `after_create_commit` / `after_save_commit` fire.
4. **Source locations point to the exact line.** `(app/models/post.rb:11)` means line 11 of your model file — the line where `before_validation :method_name` is declared.

### Nested attributes (interleaved parent + child)

When using `accepts_nested_attributes_for`, callbacks from the parent and child interleave:

```
[CallbackTracer] Post  before_validation  (app/models/post.rb:11)
[CallbackTracer] Reply before_validation  (app/models/reply.rb:9)
[CallbackTracer] Reply after_validation   (app/models/reply.rb:10)
[CallbackTracer] Post  after_validation   (app/models/post.rb:12)
[CallbackTracer] Post  before_save        (app/models/post.rb:16)
...
[CallbackTracer] Reply before_save        (app/models/reply.rb:13)
[CallbackTracer] Reply before_create      (app/models/reply.rb:18)
...
[CallbackTracer] Post  after_commit       (app/models/post.rb:31)
[CallbackTracer] Reply after_commit       (app/models/reply.rb:28)
```

This is extremely useful for understanding when child records save relative to the parent.

### Transaction rollbacks

On rollback, `after_rollback` fires but `after_commit` does not:

```
[CallbackTracer] Post before_validation   (app/models/post.rb:11)
[CallbackTracer] Post after_validation    (app/models/post.rb:12)
[CallbackTracer] Post before_save         (app/models/post.rb:16)
[CallbackTracer] Post before_create       (app/models/post.rb:21)
[CallbackTracer] Post after_create        (app/models/post.rb:23)
[CallbackTracer] Post after_save          (app/models/post.rb:18)
[CallbackTracer] Post after_rollback      (app/models/post.rb:37)
```

Notice: no `after_commit` line appears. This confirms the transaction was rolled back.

### Multiple callbacks of the same type

When a model registers multiple callbacks of the same type (common with concerns and mixins), they fire in declaration order:

```
[CallbackTracer] Comment before_validation (app/models/comment.rb:7)  0.01ms
[CallbackTracer] Comment before_validation (app/models/comment.rb:8)  0.00ms
[CallbackTracer] Comment after_validation  (app/models/comment.rb:9)  0.00ms
[CallbackTracer] Comment after_validation  (app/models/comment.rb:10) 0.00ms
```

The source locations (`:7` vs `:8`) let you tell them apart.

### Validation failures

When validation fails, only validation callbacks fire — no save/create/update/commit callbacks:

```
[CallbackTracer] Post before_validation (app/models/post.rb:11) 0.01ms
[CallbackTracer] Post after_validation  (app/models/post.rb:12) 0.01ms
```

---

## Toggling tracing at runtime

You can enable/disable tracing dynamically without restarting your app:

```ruby
# In rails console or anywhere in your code
CallbackTracer.configuration.enabled = false   # silence
CallbackTracer.configuration.enabled = true    # resume
```

---

## Production safety

The gem is safe to leave in your Gemfile's `:development, :test` group. Even if it somehow loads in production, the Railtie explicitly checks:

```ruby
CallbackTracer.setup! unless Rails.env.production?
```

No instrumentation module is prepended in production. Zero runtime overhead.

---

## How it works (technical summary)

1. A `Rails::Railtie` initializer runs when ActiveRecord loads.
2. It prepends `CallbackTracer::Tracer` onto `ActiveRecord::Base`.
3. `Tracer` overrides `run_callbacks(kind)` — the method Rails calls for every callback chain (`:validation`, `:save`, `:create`, etc.).
4. Before delegating to `super`, it reads the model's callback chain via `self.class.__callbacks[kind]` and wraps each registered callback:
   - **Symbol filters** (e.g., `before_save :set_defaults`): a module is prepended onto the instance's singleton class that wraps the method with timing and logging.
   - **Proc/lambda filters** (e.g., `before_save -> { ... }`): the proc is temporarily replaced on the callback object with a wrapped version, then restored after execution.
   - **Around callbacks**: wrapped with [enter]/[exit] logging around the yield.
5. Source locations are extracted via `Method#source_location` or `Proc#source_location`, then shortened relative to `Rails.root`.
6. All wrappers are temporary and per-invocation. They do not permanently modify the callback chain.

---

## Troubleshooting

### I don't see any output

1. Make sure you're not in production: `Rails.env` should be `development` or `test`.
2. Check that `CallbackTracer.enabled?` returns `true` in the console.
3. Check that the model isn't in `excluded_models`.
4. If using a custom `logger`, check that logger's output destination.

### Output has garbled characters

Your terminal may not support ANSI colors. Disable colorization:

```ruby
CallbackTracer.configure do |config|
  config.colorize = false
end
```

### Some callbacks show framework paths instead of app paths

Internal Rails callbacks (like autosave association callbacks) have source locations inside the `activerecord` gem. This is expected — those callbacks are registered by Rails, not your code. The path will look like:

```
(activerecord-7.1.6/lib/active_record/autosave_association.rb:160)
```

### Too much output

Exclude noisy models:

```ruby
CallbackTracer.configure do |config|
  config.excluded_models = ["AuditLog", "Session", "ActiveRecord::SchemaMigration"]
end
```

Or disable tracing entirely and re-enable only when needed:

```ruby
CallbackTracer.configuration.enabled = false
```
