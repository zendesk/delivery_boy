require "delivery_boy"

RSpec.describe DeliveryBoy::Instance do
  let(:logger) { Logger.new($stdout, level: ENV["DEBUG"] ? Logger::DEBUG : Logger::FATAL) }
  let(:config) do
    DeliveryBoy::Config.new.tap do |conf|
      conf.set(:brokers, [
        RSpec.configuration.container.connection_url
      ])
    end
  end
  let(:instance) { DeliveryBoy::Instance.new(config, logger) }

  describe "#buffer_size" do
    it "returns the number of messages in the buffer" do
      instance.produce("hello", topic: "greeting")
      instance.produce("world", topic: "greeting")

      expect(instance.buffer_size).to eq 2
    end
  end

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

  describe "#clear_buffer" do
    it "clears the buffer" do
      instance.produce("hello", topic: "greetings")
      instance.clear_buffer
    end
  end
end
