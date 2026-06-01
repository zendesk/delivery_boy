# frozen_string_literal: true

module DeliveryBoy
  # This class implements the actual logic of DeliveryBoy. The DeliveryBoy module
  # has a module-level singleton instance.
  class Instance
    def initialize(config, logger, instrumenter: NullInstrumenter.new)
      @config = config
      @logger = logger
      @instrumenter = instrumenter
    end

    def deliver(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      message_size = value.to_s.bytesize

      instrumentation_payload = {
        client_id: config.client_id,
        topic: topic,
        message_size: message_size
      }

      @instrumenter.instrument("deliver", instrumentation_payload) do
        sync_producer
          .produce(payload: value, topic: topic, **options_clone)
          .wait
      end
    end

    def deliver_async!(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      message_size = value.to_s.bytesize

      instrumentation_payload = {
        client_id: config.client_id,
        topic: topic,
        message_size: message_size,
        queue_size: async_producer_queue_size
      }

      @instrumenter.instrument("deliver_async", instrumentation_payload) do
        async_producer
          .produce(payload: value, topic: topic, **options_clone)
      end
    end

    def shutdown
      sync_producer.close if sync_producer?
      async_producer.close if async_producer?
    end

    def produce(value, topic:, **options)
      options_clone = options.clone
      if options[:create_time]
        options_clone[:timestamp] = Time.at(options[:create_time])
        options_clone.delete(:create_time)
      end

      message_size = value.to_s.bytesize

      instrumentation_payload = {
        client_id: config.client_id,
        topic: topic,
        message_size: message_size,
        buffer_size: handles.size
      }

      @instrumenter.instrument("produce_message", instrumentation_payload) do
        handle = sync_producer.produce(payload: value, topic: topic, **options_clone)
        handles.push(handle)
      end
    end

    def deliver_messages
      message_count = handles.size

      instrumentation_payload = {
        client_id: config.client_id,
        delivered_message_count: message_count
      }

      @instrumenter.instrument("deliver_messages", instrumentation_payload) do
        sync_producer.flush
        handles.clear
      end
    end

    def clear_buffer
      handles.clear
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
      @async_producer ||= begin
        producer = Rdkafka::Config.new({
          "bootstrap.servers": config.brokers.join(","),
          "queue.buffering.backpressure.threshold": config.delivery_threshold,
          "queue.buffering.max.ms": config.delivery_interval_ms
        }.merge(producer_options)).producer

        producer.delivery_callback = delivery_callback
        producer
      end
    end

    def async_producer?
      !@async_producer.nil?
    end

    def async_producer_queue_size
      return 0 unless async_producer?
      # rdkafka doesn't expose queue size directly, return 0 as approximation
      0
    end

    def delivery_callback
      instrumenter = @instrumenter
      client_id = config.client_id

      proc do |delivery_report|
        if delivery_report.error
          instrumenter.instrument("delivery_error", {
            client_id: client_id,
            error: delivery_report.error
          })
        else
          instrumenter.instrument("ack_message", {
            client_id: client_id,
            topic: delivery_report.topic_name,
            partition: delivery_report.partition,
            offset: delivery_report.offset
          })
        end
      end
    end

    def kafka
      @kafka ||= Rdkafka::Config.new({
        "bootstrap.servers": config.brokers.join(",")
      }.merge(producer_options))
    end

    def sasl_options
      return {} unless config.sasl_mechanism && !config.sasl_mechanism.empty?

      config.validate_aws_msk_iam! if config.sasl_enabled?

      options = {}

      mechanism = config.sasl_mechanism.upcase

      case mechanism
      when "GSSAPI"
        options.merge!(gssapi_options)
      when "PLAIN"
        options.merge!(plain_options)
      when "SCRAM-SHA-256", "SCRAM-SHA-512"
        options["sasl.mechanism"] = mechanism
        options.merge!(scram_options)
      when "OAUTHBEARER"
        options.merge!(oauthbearer_options)
      else
        logger.warn "Unknown SASL mechanism: #{config.sasl_mechanism}"
      end

      options.compact
    end

    def gssapi_options
      {
        "sasl.mechanism" => "GSSAPI",
        "sasl.kerberos.principal" => config.sasl_gssapi_principal,
        "sasl.kerberos.keytab" => config.sasl_gssapi_keytab
      }
    end

    def plain_options
      username = config.sasl_username || config.sasl_plain_username
      password = config.sasl_password || config.sasl_plain_password

      if username.nil? || username.to_s.empty? || password.nil? || password.to_s.empty?
        raise ConfigError, "PLAIN authentication requires sasl_username and sasl_password to be set"
      end

      # Note: sasl_plain_authzid doesn't have a librdkafka equivalent
      # Log warning if set, but don't fail
      if config.sasl_plain_authzid && !config.sasl_plain_authzid.empty?
        logger.warn "sasl_plain_authzid is not supported by librdkafka and will be ignored"
      end

      {
        "sasl.mechanism" => "PLAIN",
        "sasl.username" => username,
        "sasl.password" => password
      }
    end

    def scram_options
      username = config.sasl_username || config.sasl_scram_username
      password = config.sasl_password || config.sasl_scram_password

      if username.nil? || username.to_s.empty? || password.nil? || password.to_s.empty?
        raise ConfigError, "SCRAM authentication requires sasl_username and sasl_password to be set"
      end

      {
        "sasl.username" => username,
        "sasl.password" => password
      }
    end

    def oauthbearer_options
      # Check for legacy token provider (not supported)
      if config.sasl_oauth_token_provider
        raise ConfigError, <<~ERROR
          sasl_oauth_token_provider is no longer supported with librdkafka.

          Migration options:
          1. Use OIDC configuration (recommended for OIDC providers like Auth0, Okta):
             config.sasl_oauthbearer_method = "oidc"
             config.sasl_oauthbearer_client_id = "your-client-id"
             config.sasl_oauthbearer_client_secret = "your-client-secret"
             config.sasl_oauthbearer_token_endpoint_url = "https://auth.example.com/oauth/token"

          2. Use SCRAM-SHA-256/512 as an alternative authentication method.

          See: https://github.com/zendesk/delivery_boy/blob/master/MIGRATION.md#oauthbearer
        ERROR
      end

      if config.sasl_oauthbearer_method&.downcase == "oidc"
        if config.sasl_oauthbearer_client_id.nil? || config.sasl_oauthbearer_client_id.empty?
          raise ConfigError, "OAUTHBEARER OIDC requires sasl_oauthbearer_client_id to be set"
        end
        if config.sasl_oauthbearer_client_secret.nil? || config.sasl_oauthbearer_client_secret.empty?
          raise ConfigError, "OAUTHBEARER OIDC requires sasl_oauthbearer_client_secret to be set"
        end
        if config.sasl_oauthbearer_token_endpoint_url.nil? || config.sasl_oauthbearer_token_endpoint_url.empty?
          raise ConfigError, "OAUTHBEARER OIDC requires sasl_oauthbearer_token_endpoint_url to be set"
        end
      else
        raise ConfigError, <<~ERROR
          OAUTHBEARER requires OIDC configuration.

          Set the following options:
            config.sasl_oauthbearer_method = "oidc"
            config.sasl_oauthbearer_client_id = "your-client-id"
            config.sasl_oauthbearer_client_secret = "your-client-secret"
            config.sasl_oauthbearer_token_endpoint_url = "https://auth.example.com/oauth/token"
        ERROR
      end

      options = {
        "sasl.mechanism" => "OAUTHBEARER",
        "sasl.oauthbearer.method" => "oidc",
        "sasl.oauthbearer.client.id" => config.sasl_oauthbearer_client_id,
        "sasl.oauthbearer.client.secret" => config.sasl_oauthbearer_client_secret,
        "sasl.oauthbearer.token.endpoint.url" => config.sasl_oauthbearer_token_endpoint_url
      }

      options["sasl.oauthbearer.scope"] = config.sasl_oauthbearer_scope if config.sasl_oauthbearer_scope
      options["sasl.oauthbearer.extensions"] = config.sasl_oauthbearer_extensions if config.sasl_oauthbearer_extensions

      options
    end

    def security_protocol
      has_ssl = config.ssl_ca_cert || config.ssl_ca_cert_file_path
      has_sasl = config.sasl_enabled? || config.sasl_gssapi_principal

      if config.sasl_over_ssl == false && has_ssl
        raise ConfigError, <<~ERROR
          sasl_over_ssl=false with SSL certificates configured is not supported by librdkafka.

          librdkafka's security.protocol cannot express "SSL for verification but SASL over plaintext".

          Options:
          1. Remove SSL certificate configuration to use SASL_PLAINTEXT
          2. Remove sasl_over_ssl=false to use SASL_SSL (recommended)

          Note: sasl_over_ssl is deprecated and will be removed in a future version.
        ERROR
      end

      if has_sasl && has_ssl
        "SASL_SSL"
      elsif has_sasl
        "SASL_PLAINTEXT"
      elsif has_ssl
        "SSL"
      else
        "PLAINTEXT"
      end
    end

    def producer_options
      if config.transactional? && config.transactional_id.nil?
        raise "transactional_id must be set"
      end

      {
        "client.id": config.client_id,
        "socket.connection.setup.timeout.ms": config.connection_timeout_ms,
        "socket.timeout.ms": config.socket_timeout_ms,
        "request.required.acks": config.required_acks,
        "request.timeout.ms": config.ack_timeout_ms,
        "message.send.max.retries": config.max_retries,
        "retry.backoff.ms": config.retry_backoff_ms,
        "queue.buffering.max.messages": config.max_buffer_size,
        "queue.buffering.max.kbytes": config.max_buffer_kbytesize,
        "compression.codec": config.compression_codec, # values none, gzip, snappy, lz4, zstd
        "enable.idempotence": config.idempotent,
        "transactional.id": config.transactional_id,
        "transaction.timeout.ms": config.transactional_timeout_ms,
        "security.protocol": security_protocol,
        "ssl.ca.pem": config.ssl_ca_cert,
        "ssl.ca.location": config.ssl_ca_cert_file_path,
        "ssl.certificate.pem": config.ssl_client_cert,
        "ssl.key.pem": config.ssl_client_cert_key,
        "ssl.key.password": config.ssl_client_cert_key_password,
        "enable.ssl.certificate.verification": config.ssl_verify_hostname
      }.merge(sasl_options).compact
    end

    def handles
      Thread.current[:delivery_boy_handles] ||= []
    end
  end
end
