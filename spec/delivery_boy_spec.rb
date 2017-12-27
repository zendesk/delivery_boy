require "delivery_boy"

describe DeliveryBoy do
  describe ".deliver_async" do
    it "delivers the message using .deliver_async!" do
      DeliveryBoy.test_mode!

      DeliveryBoy.deliver_async("hello", topic: "greetings")
      DeliveryBoy.deliver_async("world", topic: "greetings")

      messages = DeliveryBoy.testing.messages_for("greetings")

      expect(messages.count).to eq 2

      expect(messages[0].value).to eq "hello"
      expect(messages[0].offset).to eq 0

      expect(messages[1].value).to eq "world"
      expect(messages[1].offset).to eq 1
    end
  end
end
