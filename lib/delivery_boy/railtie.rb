module DeliveryBoy
  class Railtie < Rails::Railtie
    initializer "delivery_boy.load_config" do
      DeliveryBoy.config.load_file("config/delivery_boy.yml", Rails.env)
    end
  end
end
