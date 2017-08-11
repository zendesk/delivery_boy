require "delivery_boy/config"

RSpec.describe DeliveryBoy::Config do
  let(:env) { Hash.new }
  let(:config) { DeliveryBoy::Config.new(env: env) }

  describe "#brokers" do
    it "defaults to localhost" do
      expect(config.brokers).to eq ["localhost:9092"]
    end
  end
end
