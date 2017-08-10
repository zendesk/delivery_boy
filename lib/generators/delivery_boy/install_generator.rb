module DeliveryBoy
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../", __FILE__)

      def create_config_file
        template "config_file.yml.erb", "config/delivery_boy.yml"
      end
    end
  end
end
