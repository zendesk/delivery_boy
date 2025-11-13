require "delivery_boy"

DeliveryBoy.test_mode!
raise 'wtf'

RSpec.configure do |config|
  # Clear the messages after each example.
  config.after(:each) do
    DeliveryBoy.testing.clear
  end
end
