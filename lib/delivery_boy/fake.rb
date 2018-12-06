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
      @delivery_lock = Mutex.new
    end

    def deliver(value, topic:, key: nil, partition: nil, partition_key: nil, create_time: Time.now)
      @delivery_lock.synchronize do
        offset = @messages[topic].count
        message = FakeMessage.new(value, topic, key, offset, partition, partition_key, create_time)

        @messages[topic] << message
      end

      nil
    end

    alias deliver_async! deliver

    def shutdown
      clear
    end

    # Clear all messages stored in memory.
    def clear
      @delivery_lock.synchronize do
        @messages.clear
      end
    end

    # Return all messages written to the specified topic.
    def messages_for(topic)
      @delivery_lock.synchronize do
        # Return a clone so that the list of messages can be traversed
        # without worrying about a concurrent modification
        @messages[topic].clone
      end
    end
  end
end
