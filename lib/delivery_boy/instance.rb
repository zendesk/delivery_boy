module DeliveryBoy
  # This class implements the actual logic of DeliveryBoy. The DeliveryBoy module
  # has a module-level singleton instance.
  class Instance
    def initialize(config, logger)
      @config = config
      @logger = logger
      @handles = []
    end

    def deliver(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      sync_producer
        .produce(payload: value, topic: topic, **options_clone)
        .wait
    end

    def deliver_async!(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      async_producer
        .produce(payload: value, topic: topic, **options_clone)
    end

    def shutdown
      sync_producer.close if sync_producer?
      async_producer.close if async_producer?
    end

    def produce(value, topic:, **options)
      handle = sync_producer.produce(payload: value, topic: topic, **options)
      handles.push(handle)
    end

    def deliver_messages
      handles.each(&:wait)
      handles.clear
    end

    def clear_buffer
      handles.clear_buffer
    end

    def buffer_size
      handles.size
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
      @async_producer ||= Rdkafka::Config.new({
        "bootstrap.servers": config.brokers.join(","),
        "queue.buffering.backpressure.threshold": config.delivery_threshold,
        "queue.buffering.max.ms": config.delivery_interval_ms
      }.merge(producer_options)).producer
    end

    def async_producer?
      !@async_producer.nil?
    end

    def kafka
      @kafka ||= Rdkafka::Config.new({
        "bootstrap.servers": config.brokers.join(",")
      }.merge(producer_options))
    end

    # Options for both the sync and async producers.
    def producer_options
      if config.transactional? && config.transactional_id.nil?
        raise "transactional_id must be set"
      end

      {
        "socket.connection.setup.timeout.ms": config.connection_timeout_ms,
        "socket.timeout.ms": config.socket_timeout_ms,
        "request.required.acks": config.required_acks,
        "request.timeout.ms": config.ack_timeout,
        "message.send.max.retries": config.max_retries,
        "retry.backoff.ms": config.retry_backoff,
        "queue.buffering.max.messages": config.max_buffer_size,
        "queue.buffering.max.kbytes": config.max_buffer_bytesize,
        "compression.codec": config.compression_codec, # values none, gzip, snappy, lz4, zstd
        "enable.idempotence": config.idempotent,
        "transactional.id": config.transactional_id,
        "transaction.timeout.ms": config.transactional_timeout_ms,

        # SSL options
        "ssl.ca.pem": config.ssl_ca_cert,
        "ssl.ca.location": config.ssl_ca_cert_file_path,
        "ssl.certificate.pem": config.ssl_client_cert,
        "ssl.key.pem": config.ssl_client_cert_key,
        "ssl.key.password": config.ssl_client_cert_key_password,
        # ssl_ca_certs_from_system: config.ssl_ca_certs_from_system, # TODO: there is no corresponding librdkafka option. check what this does
        # ssl_verify_hostname: config.ssl_verify_hostname, # check
        "sasl.kerberos.principal": config.sasl_gssapi_principal,
        "sasl.kerberos.keytab": config.sasl_gssapi_keytab
        # sasl_plain_authzid: config.sasl_plain_authzid, # no corresponding librdkafka option, check
        # 'sasl.username': config.sasl_plain_username,
        # 'sasl.password': config.sasl_plain_password,
        # 'sasl.username': config.sasl_scram_username,
        # 'sasl.passord': config.sasl_scram_password,
        # 'sasl.mechanism': config.sasl_scram_mechanism,
        # sasl_over_ssl: config.sasl_over_ssl, # conditional value check again
        # sasl_oauth_token_provider: config.sasl_oauth_token_provider, # cb code
        # sasl_aws_msk_iam_access_key_id: config.sasl_aws_msk_iam_access_key_id, # not supported
        # sasl_aws_msk_iam_secret_key_id: config.sasl_aws_msk_iam_secret_key_id, # not supported
        # sasl_aws_msk_iam_session_token: config.sasl_aws_msk_iam_session_token, # not supported
        # sasl_aws_msk_iam_aws_region: config.sasl_aws_msk_iam_aws_region # not supported
      }
    end

    private

    attr_reader :handles
  end
end
