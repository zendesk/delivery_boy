module DeliveryBoy
  # This class implements the actual logic of DeliveryBoy. The DeliveryBoy module
  # has a module-level singleton instance.
  class Instance
    def initialize(config, logger)
      @config = config
      @logger = logger
      @async_producer = nil
    end

    def deliver(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      handle = sync_producer.produce(payload: value, topic: topic, **options_clone)
      handle.wait
    rescue
      # Make sure to clear any buffered messages if there's an error.
      clear_buffer

      raise
    end

    def deliver_async!(value, topic:, **options)
      async_producer.produce(value, topic: topic, **options)
    end

    def shutdown
      sync_producer.close if sync_producer?
      async_producer.shutdown if async_producer?

      Thread.current[:delivery_boy_sync_producer] = nil
    end

    def produce(value, topic:, **options)
      sync_producer.produce(value, topic: topic, **options)
    end

    def deliver_messages
      sync_producer.deliver_messages
    end

    def clear_buffer
      # sync_producer.clear_buffer
    end

    def buffer_size
      sync_producer.buffer_size
    end

    private

    attr_reader :config, :logger

    def sync_producer
      # We want synchronous producers to be per-thread in order to avoid problems with
      # concurrent deliveries.
      Thread.current[:delivery_boy_sync_producer] ||= kafka.producer
    end

    def sync_producer?
      Thread.current.key?(:delivery_boy_sync_producer)
    end

    def async_producer
      # The async producer doesn't have to be per-thread, since all deliveries are
      # performed by a single background thread.
      @async_producer ||= kafka.async_producer(
        max_queue_size: config.max_queue_size,
        delivery_threshold: config.delivery_threshold,
        delivery_interval: config.delivery_interval,
        **producer_options
      )
    end

    def async_producer?
      !@async_producer.nil?
    end

    def kafka
      @kafka ||= Rdkafka::Config.new({
        "bootstrap.servers": ENV.fetch('KAFKA_HOST')
      }.merge(producer_options))
    end

    # Options for both the sync and async producers.
    def producer_options
      {
        'request.required.acks': config.required_acks,
        'request.timeout.ms': config.ack_timeout,
        'message.send.max.retries': config.max_retries,
        'retry.backoff.ms': config.retry_backoff,
        'queue.buffering.max.messages': config.max_buffer_size,
        'queue.buffering.max.kbytes': config.max_buffer_bytesize,
        'compression.codec': config.compression_codec,
        'enable.idempotence': config.idempotent,
        'isolation.level': config.isolation_level,
        'transaction.timeout.ms': config.transactional_timeout_ms,
      }
    end
  end
end
