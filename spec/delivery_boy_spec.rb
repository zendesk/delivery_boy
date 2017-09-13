require "delivery_boy"

describe DeliveryBoy do
  describe ".deliver_async" do
    it "delivers the message using .deliver_async!" do
      DeliveryBoy.test_mode!

      DeliveryBoy.deliver_async("hello", topic: "greetings")

      messages = DeliveryBoy.testing.messages_for("greetings")

      expect(messages.count).to eq 1
      expect(messages.first.value).to eq "hello"
    end
  end
end
