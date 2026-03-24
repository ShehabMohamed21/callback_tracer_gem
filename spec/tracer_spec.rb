require "spec_helper"

RSpec.describe CallbackTracer::Tracer do
  before(:all) do
    CallbackTracer.setup!
  end

  let(:test_model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "test_models"
      def self.name; "TestModel"; end

      before_validation :log_before_validation
      after_validation :log_after_validation
      before_save :log_before_save
      after_save :log_after_save
      before_create :log_before_create
      after_create :log_after_create

      private

      def log_before_validation; end
      def log_after_validation; end
      def log_before_save; end
      def log_after_save; end
      def log_before_create; end
      def log_after_create; end
    end
  end

  it "traces callbacks on create" do
    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
    end
    output = capture_output { test_model_class.create!(name: "test") }

    expect(output).to include("[CallbackTracer] TestModel")
    expect(output).to include("before_validation")
    expect(output).to include("after_validation")
    expect(output).to include("before_save")
    expect(output).to include("before_create")
    expect(output).to include("after_create")
    expect(output).to include("after_save")
  end

  it "does not trace when disabled" do
    CallbackTracer.configure { |c| c.enabled = false }
    output = capture_output { test_model_class.create!(name: "test") }

    expect(output).not_to include("[CallbackTracer]")
  end

  it "does not trace excluded models" do
    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
      c.excluded_models = ["TestModel"]
    end
    output = capture_output { test_model_class.create!(name: "test") }

    expect(output).not_to include("[CallbackTracer]")
  end

  it "includes source location" do
    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
    end
    output = capture_output { test_model_class.create!(name: "test") }

    expect(output).to match(/\(.+:\d+\)/)
  end

  it "includes timing" do
    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
    end
    output = capture_output { test_model_class.create!(name: "test") }

    expect(output).to match(/\d+\.\d+ms/)
  end

  it "supports custom logger" do
    log_output = StringIO.new
    custom_logger = Logger.new(log_output)
    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
      c.logger = custom_logger
    end

    test_model_class.create!(name: "test")
    CallbackTracer.flush_buffer!

    expect(log_output.string).to include("[CallbackTracer]")
  end

  it "traces around callbacks" do
    around_model = Class.new(ActiveRecord::Base) do
      self.table_name = "test_models"
      def self.name; "AroundTestModel"; end

      around_save :log_around_save

      private

      def log_around_save
        yield
      end
    end

    CallbackTracer.configure do |c|
      c.enabled = true
      c.colorize = false
    end
    output = capture_output { around_model.create!(name: "test") }

    expect(output).to include("around_save [enter]")
    expect(output).to include("around_save [exit]")
  end

  private

  def capture_output
    output = StringIO.new
    log_logger = Logger.new(output, formatter: proc { |_, _, _, msg| "#{msg}\n" })
    CallbackTracer.configure { |c| c.logger = log_logger }
    yield
    CallbackTracer.flush_buffer!
    output.string
  end
end
