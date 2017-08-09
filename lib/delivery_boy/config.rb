require "delivery_boy/env_config/loader"

module DeliveryBoy
  ConfigError = Class.new(StandardError)

  class Config
    VARIABLES = %w[
      ack_timeout
      compression_codec
      compression_threshold
      connect_timeout
      delivery_interval
      delivery_threshold
      max_buffer_bytesize
      max_buffer_size
      max_queue_size
      max_retries
      required_acks
      retry_backoff
      socket_timeout
      ssl_ca_cert
      ssl_client_cert
      ssl_client_cert_key
    ]

    DEFAULTS = {
      brokers: ["localhost:9092"],
      client_id: "delivery_boy",
    }

    attr_accessor(*VARIABLES)

    def initialize(env:)
      load_config(DEFAULTS)
      load_env(env)
    end

    private

    def load_config(config)
      config.each do |variable, value|
        set(variable, value)
      end
    end

    def load_env(env)
      loader = EnvConfigLoader.new(env, self)

      loader.integer :ack_timeout
      loader.string :compression_codec
      loader.integer :compression_threshold
      loader.integer :connect_timeout
      loader.integer :delivery_interval
      loader.integer :delivery_threshold
      loader.integer :max_buffer_bytesize
      loader.integer :max_buffer_size
      loader.integer :max_queue_size
      loader.integer :max_retries
      loader.integer :required_acks
      loader.integer :retry_backoff
      loader.integer :socket_timeout
      loader.string :ssl_ca_cert
      loader.string :ssl_client_cert
      loader.string :ssl_client_cert_key

      loader.validate!
    end

    def set(variable, value)
      unless VARIABLES.include?(variable.to_s)
        raise ConfigError, "unknown configuration variable `#{variable}`"
      end

      instance_variable_set("@#{variable}", value)
    end
  end
end
