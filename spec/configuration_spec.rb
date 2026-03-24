require "spec_helper"

RSpec.describe CallbackTracer::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "is disabled by default" do
      expect(config.enabled).to be false
    end

    it "has no excluded models" do
      expect(config.excluded_models).to eq([])
    end

    it "has colorize enabled" do
      expect(config.colorize).to be true
    end

    it "has no logger by default" do
      expect(config.logger).to be_nil
    end
  end

  describe "#excluded?" do
    before do
      config.excluded_models = ["ExcludedModel"]
    end

    it "returns true for excluded model" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "excluded_models"
        def self.name; "ExcludedModel"; end
      end
      expect(config.excluded?(model_class)).to be true
    end

    it "returns false for non-excluded model" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "test_models"
        def self.name; "TestModel"; end
      end
      expect(config.excluded?(model_class)).to be false
    end
  end
end
