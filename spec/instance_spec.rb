require "delivery_boy"

RSpec.describe DeliveryBoy::Instance do
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }
  let(:config) { DeliveryBoy::Config.new }
  let(:instance) { DeliveryBoy::Instance.new(config, logger) }

  before :all do
    kafka = Kafka.new(DeliveryBoy.config.brokers, logger: DeliveryBoy.logger)
    begin
      kafka.create_topic("greetings")
    rescue => e
      DeliveryBoy.logger.warn "Topic `greetings` already created"
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
end
