module DeliveryBoy

  # A fake implementation that is useful for testing.
  class Fake
    FakeMessage = Struct.new(:value, :key, :topic, :partition, :partition_key)

    def initialize
      @messages = Hash.new {|h, k| h[k] = [] }
    end

    def deliver(value, topic:, **options)
      message = FakeMessage.new(value: value, topic: topic, **options)
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
