require "delivery_boy"

RSpec.describe DeliveryBoy do
  after(:each) do
    DeliveryBoy.testing.clear
    DeliveryBoy.clear_config!
  end

  describe ".deliver" do
    it "delivers the message using .deliver" do
      time1 = Time.now
      time2 = Time.now
      DeliveryBoy.deliver("hello", topic: "greetings", create_time: time1)
      DeliveryBoy.deliver("world", topic: "greetings", create_time: time2)

      received_messages = consume_messages(topic: "greetings", max_messages: 2)

      expect(received_messages.map(&:payload)).to eql(["hello", "world"])
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

      time1 = Time.now
      time2 = Time.now
      DeliveryBoy.produce("hello", topic: "greetings", create_time: time1)
      DeliveryBoy.produce("world", topic: "greetings", create_time: time2)

      expect(DeliveryBoy.testing.messages_for("greetings").count).to eq 0
    end

    it "sends produced messages after calling deliver_messages" do
      DeliveryBoy.test_mode!

      time1 = Time.now
      time2 = Time.now
      DeliveryBoy.produce("hello", topic: "greetings", create_time: time1)
      DeliveryBoy.produce("world", topic: "greetings", create_time: time2)
      DeliveryBoy.deliver_messages

      messages = DeliveryBoy.testing.messages_for("greetings")

      expect(messages.count).to eq 2

      expect(messages[0].value).to eq "hello"
      expect(messages[0].offset).to eq 0
      expect(messages[0].create_time).to eq time1

      expect(messages[1].value).to eq "world"
      expect(messages[1].offset).to eq 1
      expect(messages[1].create_time).to eq time2
    end
  end

  describe "with invalid config in ENV" do
    before { ENV["DELIVERY_BOY_ACK_TIMEOUT"] = "true" }
    after { ENV.delete("DELIVERY_BOY_ACK_TIMEOUT") }

    it "raises ConfigError" do
      DeliveryBoy.test_mode!

      expect { DeliveryBoy.config }.to raise_error(DeliveryBoy::ConfigError, '"true" is not an integer')
    end
  end

  def consume_messages(topic:, max_messages:, max_attempts: 20)
    consumer.subscribe(topic)

    messages = []

    attempts = 0
    while messages.count < max_messages && attempts < max_attempts
      attempts += 1

      while (message = consumer.poll(1000))
        messages << message
      end

      sleep 0.1
    end

    messages
  ensure
    consumer.close
  end

  def kafka_host
    ENV.fetch('KAFKA_HOST', 'localhost:9002')
  end

  let(:consumer) {
    Rdkafka::Config.new({
      "bootstrap.servers": kafka_host,
      "group.id": "ruby-test",
      "auto.offset.reset": "beginning"
    }).consumer
  }
end
