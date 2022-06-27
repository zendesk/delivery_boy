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
      sync_producer.produce(value, topic: topic, **options)
      sync_producer.deliver_messages
    rescue
      # Make sure to clear any buffered messages if there's an error.
      clear_buffer

      raise
    end

    def deliver_async!(value, topic:, **options)
      async_producer.produce(value, topic: topic, **options)
    end

    def shutdown
      sync_producer.shutdown if sync_producer?
      async_producer.shutdown if async_producer?
    end

    def produce(value, topic:, **options)
      sync_producer.produce(value, topic: topic, **options)
    end

    def deliver_messages
      sync_producer.deliver_messages
    end

    def clear_buffer
      sync_producer.clear_buffer
    end

    def buffer_size
      sync_producer.buffer_size
    end

    private

    attr_reader :config, :logger

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
        ssl_ca_cert_file_path: config.ssl_ca_cert_file_path,
        ssl_client_cert: config.ssl_client_cert,
        ssl_client_cert_key: config.ssl_client_cert_key,
        ssl_client_cert_key_password: config.ssl_client_cert_key_password,
        ssl_ca_certs_from_system: config.ssl_ca_certs_from_system,
        ssl_verify_hostname: config.ssl_verify_hostname,
        sasl_gssapi_principal: config.sasl_gssapi_principal,
        sasl_gssapi_keytab: config.sasl_gssapi_keytab,
        sasl_plain_authzid: config.sasl_plain_authzid,
        sasl_plain_username: config.sasl_plain_username,
        sasl_plain_password: config.sasl_plain_password,
        sasl_scram_username: config.sasl_scram_username,
        sasl_scram_password: config.sasl_scram_password,
        sasl_scram_mechanism: config.sasl_scram_mechanism,
        sasl_over_ssl: config.sasl_over_ssl,
        sasl_oauth_token_provider: config.sasl_oauth_token_provider,
        sasl_aws_msk_iam_access_key_id: config.sasl_aws_msk_iam_access_key_id,
        sasl_aws_msk_iam_secret_key_id: config.sasl_aws_msk_iam_secret_key_id,
        sasl_aws_msk_iam_session_token: config.sasl_aws_msk_iam_session_token,
        sasl_aws_msk_iam_aws_region: config.sasl_aws_msk_iam_aws_region
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
        compression_codec: (config.compression_codec.to_sym if config.compression_codec),
        compression_threshold: config.compression_threshold,
        idempotent: config.idempotent,
        transactional: config.transactional,
        transactional_timeout: config.transactional_timeout,
      }
    end
  end
end
