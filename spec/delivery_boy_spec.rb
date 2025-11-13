require "spec_helper"
require "delivery_boy"

RSpec.describe DeliveryBoy do
  before(:all) do
    create_topic("greetings")
  end

  def create_topic(topic)
    Rdkafka::Config.new({
      "bootstrap.servers": RSpec.configuration.container.connection_url
    })
      .admin
      .create_topic(topic, 1, 1)
      .wait(max_wait_timeout: 5)
  rescue Rdkafka::RdkafkaError => e
    raise unless e.code == :topic_already_exists
  end

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
  end

  describe ".deliver_async!" do
    it "delivers the message" do
      received_messages = consume_new_messages(topic: topic_name, max_messages: 2) do
        DeliveryBoy.deliver_async!(message1, topic: topic_name)
        DeliveryBoy.deliver_async!(message2, topic: topic_name)
      end

      expect(received_messages.map(&:payload)).to eql([message1, message2])
    end
  end

  describe ".produce and .deliver_messages" do
    it "sends message and adds to the hanldes buffer" do
      DeliveryBoy.produce("hello", topic: topic_name)
      DeliveryBoy.produce("world", topic: topic_name)

      expect(DeliveryBoy.send(:instance).send(:handles).size).to eq 2
      expect(DeliveryBoy.send(:instance).send(:handles).map(&:pending?)).to all be(true)
    end

    it "waits on producing messages" do
      DeliveryBoy.produce("hello", topic: topic_name)
      DeliveryBoy.produce("world", topic: topic_name)

      handles = DeliveryBoy.send(:instance).send(:handles)

      DeliveryBoy.deliver_messages

      expect(handles.map(&:pending?)).to all be(false)
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

  describe "with invalid config in ENV" do
    before { ENV["DELIVERY_BOY_ACK_TIMEOUT"] = "true" }
    after { ENV.delete("DELIVERY_BOY_ACK_TIMEOUT") }

    it "raises ConfigError" do
      # reset cached config
      DeliveryBoy.clear_config!
      DeliveryBoy.test_mode!

      expect { DeliveryBoy.config }.to raise_error(DeliveryBoy::ConfigError, '"true" is not an integer')
    end
  end

  def consume_new_messages(topic:, max_messages:, max_attempts: 20, &block)
    consumer = Rdkafka::Config.new({
      "bootstrap.servers": RSpec.configuration.container.connection_url,
      "group.id": "ruby-test" + SecureRandom.hex(8),
      "auto.offset.reset": "earliest"
    }).consumer

    messages = []

    consumer.subscribe(topic)
    puts "subscribed to topic #{topic}"

    # wait for any in-flight messages to arrive to avoid flaky tests
    sleep 5

    attempts = 0
    existing_message = true

    while existing_message
      p existing_message = consumer.poll(100)
    end

    puts "Existing messages consumed, starting to execute block to produce new messages"

    block.call

    while messages.count < max_messages && attempts < max_attempts
      attempts += 1

      puts "Polling for messages, attempt #{attempts}"

      message = consumer.poll(100)
      if message
        messages << message
      end
    end

    messages
  ensure
    puts "Closing consumer"
    consumer.close
  end
end
