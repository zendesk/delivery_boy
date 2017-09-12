module DeliveryBoy
  class Railtie < Rails::Railtie
    initializer "delivery_boy.load_config" do
      config = DeliveryBoy.config
      config_file = "config/delivery_boy.yml"

      if File.exist?(config_file)
        config.load_file(config_file, Rails.env)
      end

      if config.datadog_enabled
        require "kafka/datadog"

        Kafka::Datadog.host = config.datadog_host if config.datadog_host.present?
        Kafka::Datadog.port = config.datadog_port if config.datadog_port.present?
        Kafka::Datadog.namespace = config.datadog_namespace if config.datadog_namespace.present?
        Kafka::Datadog.tags = config.datadog_tags if config.datadog_tags.present?
      end
    end
  end
end
