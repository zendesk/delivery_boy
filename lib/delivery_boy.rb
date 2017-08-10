require "logger"
require "kafka"
require "delivery_boy/version"
require "delivery_boy/config"
require "delivery_boy/railtie" if defined?(Rails)

module DeliveryBoy
  class << self
    def deliver(value, topic:, **options)
      sync_producer.produce(value, topic: topic, **options)
      sync_producer.deliver_messages
    end

    def deliver_async(value, topic:, **options)
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
      Thread.current[:delivery_boy_sync_producer] ||= kafka.producer(**producer_options)
    end

    def sync_producer?
      Thread.current.key?(:delivery_boy_sync_producer)
    end

    def async_producer
      Thread.current[:delivery_boy_async_producer] ||= kafka.async_producer(
        max_queue_size: config.max_queue_size,
        delivery_threshold: config.delivery_threshold,
        delivery_interval: config.delivery_interval,
        **producer_options,
      )
    end

    def async_producer?
      Thread.current.key?(:delivery_boy_async_producer)
    end

    def kafka
      Thread.current[:delivery_boy_kafka] ||= Kafka.new(
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
