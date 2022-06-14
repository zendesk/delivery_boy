require "delivery_boy"

RSpec.describe DeliveryBoy do
  after(:each) do
    DeliveryBoy.testing.clear
    DeliveryBoy.clear_config!
  end

  describe ".deliver_async" do
    it "delivers the message using .deliver_async!" do

      time1 = Time.now
      time2 = Time.now
      # DeliveryBoy.deliver("hello", topic: "greetings", create_time: time1)
      # DeliveryBoy.deliver("world", topic: "greetings", create_time: time2)

      rdkafka_config_consumer.consumer

      rdkafka_producer = rdkafka_config_producer.producer
      ["hello", "world"].map do |m|
        rdkafka_producer.produce(
          topic: "greetings",
          key: m,
          payload: m
        )
      end.each(&:wait)
      rdkafka_producer.close

      # messages = DeliveryBoy.testing.messages_for("greetings")

      incoming_messages = wait_for_messages(topic: "greetings", expected_message_count: 2)

      expect(incoming_messages.map(&:payload)).to eql(["hello", "world"])
    end
  end

  def rdkafka_config_consumer
    Rdkafka::Config.new({
      "bootstrap.servers": "kafka.docker:9092",
      :"group.id" => "ruby-test",
      "auto.offset.reset": "beginning"
    })
  end

  def rdkafka_config_producer
    Rdkafka::Config.new({
      "bootstrap.servers": "kafka.docker:9092",
    })
  end

  def wait_for_messages(topic:, expected_message_count:)
    rdkafka_consumer = rdkafka_config_consumer.consumer
    rdkafka_consumer.subscribe(topic)

    attempts = 0
    incoming_messages = []

    while incoming_messages.count < expected_message_count && attempts < 1000
      $stderr.puts "Waiting for messages..."
      attempts += 1

      while (message = rdkafka_consumer.poll(1000))
        $stderr.puts "Received message #{message}"
        incoming_messages << message
      end

      sleep 0.1
    end

    incoming_messages
  rescue
    incoming_messages
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
end
