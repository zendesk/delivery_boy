require "delivery_boy"

DeliveryBoy.test_mode!

RSpec.configure do |config|
  # Clear the messages after each example.
  config.after(:each) do
    DeliveryBoy.testing.clear
  end
end
