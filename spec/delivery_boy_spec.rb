require "delivery_boy"

describe DeliveryBoy do
  describe ".deliver_async" do
    it "delivers the message using .deliver_async!" do
      DeliveryBoy.test_mode!

      time1 = Time.now
      time2 = Time.now
      DeliveryBoy.deliver_async("hello", topic: "greetings", create_time: time1)
      DeliveryBoy.deliver_async("world", topic: "greetings", create_time: time2)

      messages = DeliveryBoy.testing.messages_for("greetings")

      expect(messages.count).to eq 2

      expect(messages[0].value).to eq "hello"
      expect(messages[0].offset).to eq 0
      expect(messages[0].create_time).to eq time1

      expect(messages[1].value).to eq "world"
      expect(messages[1].offset).to eq 1
      expect(messages[1].create_time).to eq time2
    end
  end
end
