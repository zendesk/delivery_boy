# frozen_string_literal: true

module DeliveryBoy
  class Railtie < Rails::Railtie
    initializer "delivery_boy.load_config" do
      config = DeliveryBoy.config

      if File.exist?("config/delivery_boy.yml")
        config.load_file("config/delivery_boy.yml", Rails.env)
      end

      if File.exist?("config/delivery_boy.rb")
        require "./config/delivery_boy"
      end

      if config.datadog_enabled
        require "delivery_boy/datadog"

        DeliveryBoy::Datadog.host = config.datadog_host if config.datadog_host.present?
        DeliveryBoy::Datadog.port = config.datadog_port if config.datadog_port.present?
        DeliveryBoy::Datadog.namespace = config.datadog_namespace if config.datadog_namespace.present?
        DeliveryBoy::Datadog.tags = config.datadog_tags if config.datadog_tags.present?

        # Enable instrumentation
        DeliveryBoy.instrumenter = DeliveryBoy::Instrumenter.new(default_payload: {})
      end
    end
  end
end
