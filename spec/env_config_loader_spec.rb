require "delivery_boy/env_config_loader"

class FakeConfig
  def initialize
    @variables = {}
  end

  def set(variable, value)
    @variables[variable] = value
  end

  def method_missing(name)
    @variables[name]
  end
end

RSpec.describe DeliveryBoy::EnvConfigLoader do
  let(:env) { Hash.new }
  let(:config) { FakeConfig.new }
  let(:loader) { DeliveryBoy::EnvConfigLoader.new(env, config) }

  describe "#string" do
    it "sets a String variable" do
      env["DELIVERY_BOY_HELLO"] = "world"

      loader.string :hello

      expect(config.hello).to eq "world"
    end

    it "does nothing if the ENV variable isn't set" do
      loader.string :hello

      expect(config.hello).to eq nil
    end
  end

  describe "#string_list" do
    it "sets a String array variable" do
      env["DELIVERY_BOY_GREETINGS"] = "hello,howdy,morning"

      loader.string_list :greetings

      expect(config.greetings).to eq ["hello", "howdy", "morning"]
    end
  end

  describe "#integer" do
    it "sets an Integer variable" do
      env["DELIVERY_BOY_PUSHUPS"] = "100"

      loader.integer :pushups

      expect(config.pushups).to eq 100
    end

    it "raises ConfigError if the value isn't an integer" do
      env["DELIVERY_BOY_PUSHUPS"] = "omg"

      expect {
        loader.integer :pushups
      }.to raise_exception(DeliveryBoy::ConfigError)
    end
  end

  describe "#validate!" do
    it "raises ConfigError if an unknown config variable is set" do
      env["DELIVERY_BOY_OMG"] = "omg"

      loader.string :hello

      expect {
        loader.validate!
      }.to raise_exception(DeliveryBoy::ConfigError, "unknown config variable DELIVERY_BOY_OMG")
    end
  end
end
