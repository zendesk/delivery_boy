require "delivery_boy/config"

RSpec.describe DeliveryBoy::Config do
  let(:env) { Hash.new }
  let(:config) { DeliveryBoy::Config.new(env: env) }

  describe "#brokers" do
    it "defaults to localhost" do
      expect(config.brokers).to eq ["localhost:9092"]
    end
  end

  it "loads configuration from ENV" do
    env = {}

    DeliveryBoy::Config::VARIABLES.each do |variable|
      name = "DELIVERY_BOY_#{variable.upcase}"
      env[name] = "42"
    end

    config = DeliveryBoy::Config.new(env: env)

    DeliveryBoy::Config::VARIABLES.each do |variable|
      expect(config.get(variable)).not_to be nil
    end
  end
end
