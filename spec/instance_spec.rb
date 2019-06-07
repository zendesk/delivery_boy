require "delivery_boy"

RSpec.describe DeliveryBoy::Instance do
  let(:logger) { Logger.new($stderr) }
  let(:config) { DeliveryBoy::Config.new }
  let(:instance) { DeliveryBoy::Instance.new(config, logger) }

  describe "#deliver" do
    it "delivers a message to Kafka" do
      instance.deliver("hello", topic: "greetings")
    end
  end

  describe "#deliver_async" do
    it "delivers a message to Kafka asynchronously" do
      instance.deliver("hello", topic: "greetings")
      instance.shutdown
    end
  end

  describe "#produce and #deliver_messages" do
    it "produces and delivers a message to kafka" do
      instance.produce("hello", topic: "greeting")
      instance.deliver_messages
    end
  end
end
