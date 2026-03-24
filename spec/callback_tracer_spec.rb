require "spec_helper"

RSpec.describe CallbackTracer do
  describe ".configure" do
    it "yields the configuration" do
      CallbackTracer.configure do |config|
        config.enabled = false
        config.excluded_models = ["Foo"]
        config.colorize = false
      end

      expect(CallbackTracer.configuration.enabled).to be false
      expect(CallbackTracer.configuration.excluded_models).to eq(["Foo"])
      expect(CallbackTracer.configuration.colorize).to be false
    end
  end

  describe ".enabled?" do
    it "returns false by default" do
      expect(CallbackTracer.enabled?).to be false
    end

    it "returns false when disabled" do
      CallbackTracer.configure { |c| c.enabled = false }
      expect(CallbackTracer.enabled?).to be false
    end
  end

  describe ".setup!" do
    it "prepends Tracer onto ActiveRecord::Base" do
      CallbackTracer.setup!
      expect(ActiveRecord::Base.ancestors).to include(CallbackTracer::Tracer)
    end
  end

  describe "VERSION" do
    it "has a version number" do
      expect(CallbackTracer::VERSION).to eq("0.1.0")
    end
  end
end
