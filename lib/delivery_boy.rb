require "logger"
require "kafka"
require "delivery_boy/version"
require "delivery_boy/config"
require "delivery_boy/railtie" if defined?(Rails)

module DeliveryBoy
  class << self

    # Write a message to a specified Kafka topic synchronously.
    #
    # Keep in mind that the client will block until the message has been
    # delivered.
    #
    # @param value [String] the message value.
    # @param topic [String] the topic that the message should be written to.
    # @param key [String, nil] the message key.
    # @param partition [Integer, nil] the topic partition that the message should
    #   be written to.
    # @param partition_key [String, nil] a key used to deterministically assign
    #   a partition to the message.
    # @return [nil]
    # @raise [Kafka::BufferOverflow] if the producer's buffer is full.
    # @raise [Kafka::DeliveryFailed] if delivery failed for some reason.
    def deliver(value, topic:, **options)
      sync_producer.produce(value, topic: topic, **options)
      sync_producer.deliver_messages
    rescue
      # Make sure to clear any buffered messages if there's an error.
      sync_producer.clear_buffer

      raise
    end

    def deliver_async(value, topic:, **options)
      deliver_async!(value, topic: topic, **options)
    rescue Kafka::BufferOverflow
      logger.error "Message for `#{topic}` dropped due to buffer overflow"
    end

    def deliver_async!(value, topic:, **options)
      async_producer.produce(value, topic: topic, **options)
    end

    def shutdown
      sync_producer.shutdown if sync_producer?
      async_producer.shutdown if async_producer?
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    attr_writer :logger

    def config
      @config ||= DeliveryBoy::Config.new(env: ENV)
    end

    private

    def sync_producer
      # We want synchronous producers to be per-thread in order to avoid problems with
      # concurrent deliveries.
      Thread.current[:delivery_boy_sync_producer] ||= kafka.producer(**producer_options)
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
        **producer_options,
      )
    end

    def async_producer?
      !@async_producer.nil?
    end

    def kafka
      @kafka ||= Kafka.new(
        seed_brokers: config.brokers,
        client_id: config.client_id,
        logger: logger,
        connect_timeout: config.connect_timeout,
        socket_timeout: config.socket_timeout,
        ssl_ca_cert: config.ssl_ca_cert,
        ssl_client_cert: config.ssl_client_cert,
        ssl_client_cert_key: config.ssl_client_cert_key,
      )
    end

    # Options for both the sync and async producers.
    def producer_options
      {
        required_acks: config.required_acks,
        ack_timeout: config.ack_timeout,
        max_retries: config.max_retries,
        retry_backoff: config.retry_backoff,
        max_buffer_size: config.max_buffer_size,
        max_buffer_bytesize: config.max_buffer_bytesize,
        compression_codec: config.compression_codec,
        compression_threshold: config.compression_threshold,
      }
    end
  end
end

at_exit { DeliveryBoy.shutdown }
