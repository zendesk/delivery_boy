module DeliveryBoy
  class Railtie < Rails::Railtie
    initializer "delivery_boy.load_config" do
      config_file = "config/delivery_boy.yml"

      if File.exist?(config_file)
        DeliveryBoy.config.load_file(config_file, Rails.env)
      end
    end
  end
end
