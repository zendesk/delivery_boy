require "spec_helper"
require "delivery_boy"

RSpec.describe DeliveryBoy do
  after(:each) do
    DeliveryBoy.testing.clear
    DeliveryBoy.shutdown
    DeliveryBoy.instance_variable_set(:@instance, nil)
    Thread.current[:delivery_boy_sync_producer] = nil
  end

  let(:topic_name) { "greetings" }
  let(:message1) { "hello " + SecureRandom.hex(8) }
  let(:message2) { "world " + SecureRandom.hex(8) }

  describe ".deliver" do
    it "delivers the message" do
      received_messages = consume_new_messages(topic: topic_name, max_messages: 2) do
        DeliveryBoy.deliver(message1, topic: topic_name)
        DeliveryBoy.deliver(message2, topic: topic_name)
      end

      expect(received_messages.map(&:payload)).to eql([message1, message2])
    end

    it "blocks until messages are delivered" do
      DeliveryBoy.deliver("hello", topic: topic_name)
      DeliveryBoy.deliver("world", topic: topic_name)

      expect(DeliveryBoy.send(:instance).send(:handles).map(&:pending?)).to all be(false)
    end

    # context "when there is an error" do
    #   it "clears the buffer" do
    #     DeliveryBoy.deliver("hello", topic: topic_name)
    #     allow_any_instance_of(Rdkafka::Producer).to receive(:produce).and_raise(RuntimeError)
    #     DeliveryBoy.deliver("world", topic: topic_name) rescue nil
    #
    #     expect(DeliveryBoy.send(:instance).send(:handles).map(&:pending?)).to all be(false)
    #   end
    # end
  end

  describe ".deliver_async!" do
    it "delivers the message" do
      received_messages = consume_new_messages(topic: topic_name, max_messages: 2) do
        DeliveryBoy.deliver_async!(message1, topic: topic_name)
        DeliveryBoy.deliver_async!(message2, topic: topic_name)
      end

      expect(received_messages.map(&:payload)).to eql([message1, message2])
    end

    it "does not block" do
      DeliveryBoy.deliver_async!("hello", topic: topic_name)
      DeliveryBoy.deliver_async!("world", topic: topic_name)

      expect(DeliveryBoy.send(:instance).send(:handles).map(&:pending?)).to all be(true)
    end
  end

  describe ".configure" do
    it "allows float for .delivery_interval" do
      DeliveryBoy.configure do |config|
        config.delivery_interval = 0.05
      end

      expect(DeliveryBoy.config.delivery_interval).to eq 0.05
    end
  end

  describe ".produce and .deliver_messages" do
    it "does not send produced messages without calling deliver_messages" do
      DeliveryBoy.test_mode!

      DeliveryBoy.produce("hello", topic: topic_name)
      DeliveryBoy.produce("world", topic: topic_name)

      expect(DeliveryBoy.testing.messages_for( topic_name).count).to eq 0
    end

    it "sends produced messages after calling deliver_messages" do
      DeliveryBoy.test_mode!

      time1 = Time.now
      time2 = Time.now
      DeliveryBoy.produce("hello", topic: topic_name, create_time: time1)
      DeliveryBoy.produce("world", topic: topic_name, create_time: time2)
      DeliveryBoy.deliver_messages

      messages = DeliveryBoy.testing.messages_for( topic_name)

      expect(messages.count).to eq 2

      expect(messages[0].value).to eq "hello"
      expect(messages[0].offset).to eq 0
      expect(messages[0].create_time).to eq time1

      expect(messages[1].value).to eq "world"
      expect(messages[1].offset).to eq 1
      expect(messages[1].create_time).to eq time2
    end
  end

  xdescribe "with invalid config in ENV" do
    before { ENV["DELIVERY_BOY_ACK_TIMEOUT"] = "true" }
    after { ENV.delete("DELIVERY_BOY_ACK_TIMEOUT") }

    it "raises ConfigError" do
      DeliveryBoy.test_mode!

      expect { DeliveryBoy.config }.to raise_error(DeliveryBoy::ConfigError, '"true" is not an integer')
    end
  end


  def consume_new_messages(topic:, max_messages:, max_attempts: 20, &block)
    messages = []

    consumer.subscribe(topic)
    attempts = 0
    existing_message = true

    while existing_message
      existing_message = consumer.poll(100)
    end

    block.call

    while messages.count < max_messages && attempts < max_attempts
      attempts += 1

      message = consumer.poll(100)
      if message
        messages << message
      end
    end

    messages
  ensure
    consumer.close
  end

  def kafka_host
    # TODO: use brokers from config
    ENV.fetch('KAFKA_HOST', 'localhost:9002')
  end

  let(:consumer) {
    Rdkafka::Config.new({
      "bootstrap.servers": kafka_host,
      "group.id": "ruby-test",
      "auto.offset.reset": "end"
    }).consumer
  }
end
