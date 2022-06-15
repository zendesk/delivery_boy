require "king_konf"

module DeliveryBoy
  class Config < KingKonf::Config
    env_prefix :delivery_boy

    def transactional_timeout_ms
      transactional_timeout * 1000
    end

    def isolation_level
      transactional ? 'read_uncommitted' : 'read_committed'
    end

    def max_buffer_kbytesize
      max_buffer_bytesize / 1024
    end

    # Basic
    list :brokers, items: :string, sep: ",", default: ["localhost:9092"]
    string :client_id, default: "delivery_boy"
    string :log_level, default: nil

    # Buffering
    integer :max_buffer_bytesize, default: 10_000_000
    integer :max_buffer_size, default: 1000
    integer :max_queue_size, default: 1000

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

    # SASL authentication
    string :sasl_gssapi_principal
    string :sasl_gssapi_keytab
    string :sasl_plain_authzid, default: ''
    string :sasl_plain_username
    string :sasl_plain_password
    string :sasl_scram_username
    string :sasl_scram_password
    string :sasl_scram_mechanism
    boolean :sasl_over_ssl, default: true

    # SASL OAUTHBEARER
    attr_accessor :sasl_oauth_token_provider

    # Datadog monitoring
    boolean :datadog_enabled
    string :datadog_host
    integer :datadog_port
    string :datadog_namespace
    list :datadog_tags
  end
end
