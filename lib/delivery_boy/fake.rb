module DeliveryBoy

  # A fake implementation that is useful for testing.
  class Fake
    FakeMessage = Struct.new(:value, :topic, :key, :offset, :partition, :partition_key, :create_time) do
      def bytesize
        key.to_s.bytesize + value.to_s.bytesize
      end
    end

    def initialize
      @messages = Hash.new {|h, k| h[k] = [] }
    end

    def deliver(value, topic:, key: nil, partition: nil, partition_key: nil, create_time: Time.now)
      offset = @messages[topic].count
      message = FakeMessage.new(value, topic, key, offset, partition, partition_key, create_time)

      @messages[topic] << message

      nil
    end

    alias deliver_async! deliver

    def shutdown
      clear
    end

    # Clear all messages stored in memory.
    def clear
      @messages.clear
    end

    # Return all messages written to the specified topic.
    def messages_for(topic)
      @messages[topic]
    end
  end
end
