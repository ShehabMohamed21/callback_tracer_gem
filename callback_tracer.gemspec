require_relative "lib/callback_tracer/version"

Gem::Specification.new do |spec|
  spec.name = "callback_tracer"
  spec.version = CallbackTracer::VERSION
  spec.authors = ["Shehab Mohamed"]
  spec.email = ["shehab.mohamed2104@gmail.com"]
  spec.homepage = "https://github.com/ShehabMohamed21/callback_tracer_gem"
  spec.summary = "Trace ActiveRecord callback execution order with source locations and timing"
  spec.description = "Instruments all ActiveRecord callbacks and prints their execution order, " \
                     "source location, and timing to the terminal during development and test."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/ShehabMohamed21/callback_tracer_gem",
    "changelog_uri" => "https://github.com/ShehabMohamed21/callback_tracer_gem/blob/main/CHANGELOG.md"
  }

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0", "< 9"
  spec.add_dependency "activesupport", ">= 7.0", "< 9"
  spec.add_dependency "railties", ">= 7.0", "< 9"
end
