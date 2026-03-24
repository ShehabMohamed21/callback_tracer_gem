require "active_record"
require "callback_tracer"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :test_models, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :excluded_models, force: true do |t|
    t.string :name
    t.timestamps
  end
end

RSpec.configure do |config|
  config.before(:each) do
    CallbackTracer.reset!
  end
end
