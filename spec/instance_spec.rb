require "delivery_boy"

RSpec.describe DeliveryBoy::Instance do
  let(:logger) { Logger.new($stderr) }
  let(:config) { DeliveryBoy::Config.new }
  let(:instance) { DeliveryBoy::Instance.new(config, logger) }

  describe "#buffer_size" do
    it "returns the number of messages in the buffer" do
      instance.produce("hello", topic: "greeting")
      instance.produce("world", topic: "greeting")

      expect(instance.buffer_size).to eq 2
    end
  end

  describe "#deliver" do
    after do
      instance.shutdown
      Thread.current[:delivery_boy_sync_producer] = nil
    end

    it "delivers a message to Kafka" do
      instance.deliver("hello", topic: "greetings")
    end

    context "when transactional is set to true and transactional_id is missing" do
      before :each do
        config.transactional = true
      end

      it "raises an exception" do
        expect {
          instance.deliver("hello", topic: "greetings")
        }.to raise_error("transactional_id must be set")
      end
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
