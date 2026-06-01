require "king_konf"

module DeliveryBoy
  class Config < KingKonf::Config
    env_prefix :delivery_boy

    def connection_timeout_ms
      connect_timeout * 1000
    end

    def socket_timeout_ms
      socket_timeout * 1000
    end

    def transactional_timeout_ms
      transactional_timeout * 1000
    end

    def max_buffer_kbytesize
      max_buffer_bytesize / 1024
    end

    def delivery_interval_ms
      delivery_interval * 1000
    end

    def ack_timeout_ms
      ack_timeout * 1000
    end

    def retry_backoff_ms
      retry_backoff * 1000
    end

    def sasl_enabled?
      return false unless sasl_mechanism && !sasl_mechanism.empty?
      sasl_mechanism.upcase != "GSSAPI"
    end

    def validate_aws_msk_iam!
      if sasl_aws_msk_iam_access_key_id || sasl_aws_msk_iam_secret_key_id || sasl_aws_msk_iam_aws_region
        raise ConfigError, <<~ERROR
          AWS MSK IAM authentication is not supported by librdkafka.

          Alternatives:
          1. Use AWS MSK SCRAM-SHA-512 authentication (recommended)
             - Create SCRAM credentials in AWS Secrets Manager
             - Set sasl_mechanism = "SCRAM-SHA-512"
             - Set sasl_username and sasl_password

          2. Use mTLS (mutual TLS) with client certificates
             - Configure ssl_client_cert and ssl_client_cert_key

          See migration guide: https://github.com/zendesk/delivery_boy/blob/master/MIGRATION.md#aws-msk-iam
        ERROR
      end
    end

    # Basic
    list :brokers, items: :string, sep: ",", default: ["localhost:9092"]
    string :client_id, default: "delivery_boy"
    string :log_level, default: nil

    # Buffering (defaults match librdkafka defaults to avoid queue overflow at high throughput)
    integer :max_buffer_bytesize, default: 10_000_000
    integer :max_buffer_size, default: 100_000
    integer :max_queue_size, default: 100_000

    # Network timeouts
    integer :connect_timeout, default: 10
    integer :socket_timeout, default: 30

    # Delivery
    integer :ack_timeout, default: 5
    float :delivery_interval, default: 10
    integer :delivery_threshold, default: 100
    integer :max_retries, default: 2
    integer :required_acks, default: -1
    integer :retry_backoff, default: 1
    boolean :idempotent, default: false
    boolean :transactional, default: false
    string :transactional_id, default: nil
    integer :transactional_timeout, default: 60

    # Compression
    integer :compression_threshold, default: 1 # deprecated, not an option for RdKafka
    string :compression_codec, default: "none"

    # SSL authentication
    string :ssl_ca_cert, default: nil
    string :ssl_ca_cert_file_path
    string :ssl_client_cert, default: nil
    string :ssl_client_cert_key, default: nil
    string :ssl_client_cert_key_password, default: nil
    boolean :ssl_ca_certs_from_system, default: false
    boolean :ssl_verify_hostname, default: true

    # Supported: GSSAPI, PLAIN, SCRAM-SHA-256, SCRAM-SHA-512, OAUTHBEARER
    string :sasl_mechanism, default: nil
    # SASL authentication
    string :sasl_gssapi_principal
    string :sasl_gssapi_keytab
    string :sasl_plain_authzid, default: ""
    string :sasl_plain_username
    string :sasl_plain_password
    string :sasl_scram_username
    string :sasl_scram_password
    string :sasl_scram_mechanism
    boolean :sasl_over_ssl, default: true

    # New consolidated SASL options (librdkafka-aligned)
    string :sasl_username, default: nil
    string :sasl_password, default: nil

    # SASL OAUTHBEARER (legacy - callback-based, not supported with librdkafka)
    attr_accessor :sasl_oauth_token_provider

    # SASL OAUTHBEARER OIDC (librdkafka native support)
    string :sasl_oauthbearer_method, default: nil # "oidc" for OIDC-based auth
    string :sasl_oauthbearer_client_id, default: nil
    string :sasl_oauthbearer_client_secret, default: nil
    string :sasl_oauthbearer_token_endpoint_url, default: nil
    string :sasl_oauthbearer_scope, default: nil
    string :sasl_oauthbearer_extensions, default: nil

    # AWS IAM authentication
    string :sasl_aws_msk_iam_access_key_id
    string :sasl_aws_msk_iam_secret_key_id
    string :sasl_aws_msk_iam_aws_region
    string :sasl_aws_msk_iam_session_token, default: nil

    # Datadog monitoring
    boolean :datadog_enabled
    string :datadog_host
    integer :datadog_port
    string :datadog_namespace
    list :datadog_tags
  end
end
