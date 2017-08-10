require "delivery_boy"

DeliveryBoy.deliver_async "howdy", topic: "greetings"
DeliveryBoy.shutdown
