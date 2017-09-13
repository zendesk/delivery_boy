module DeliveryBoy

  # A fake implementation that is useful for testing.
  class Fake
    FakeMessage = Struct.new(:value, :topic, :key, :partition, :partition_key)

    def initialize
      @messages = Hash.new {|h, k| h[k] = [] }
    end

    def deliver(value, topic:, key: nil, partition: nil, partition_key: nil)
      message = FakeMessage.new(value, topic, key, partition, partition_key)
      @messages[topic] << message

      nil
    end

    alias deliver_async! deliver

    def shutdown
      @messages.clear
    end

    def messages_for(topic)
      @messages[topic]
    end
  end
end
