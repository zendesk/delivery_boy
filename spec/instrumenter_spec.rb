# frozen_string_literal: true

require "spec_helper"
require "active_support"
require "delivery_boy/instrumenter"

RSpec.describe DeliveryBoy::Instrumenter do
  let(:instrumenter) { described_class.new(default_payload: {client_id: "test-client"}) }

  after do
    ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
  end

  describe "#instrument" do
    it "emits ActiveSupport::Notifications events with delivery_boy namespace" do
      events = []
      @subscription = ActiveSupport::Notifications.subscribe("test_event.delivery_boy") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      instrumenter.instrument("test_event", {topic: "test-topic"}) {}

      expect(events.size).to eq(1)
      expect(events.first.payload).to include(client_id: "test-client", topic: "test-topic")
    end

    it "merges default payload with event payload" do
      events = []
      @subscription = ActiveSupport::Notifications.subscribe("merge_test.delivery_boy") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      instrumenter.instrument("merge_test", {extra: "value"}) {}

      expect(events.first.payload).to eq(client_id: "test-client", extra: "value")
    end

    it "measures duration when block is provided" do
      events = []
      @subscription = ActiveSupport::Notifications.subscribe("duration_test.delivery_boy") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      instrumenter.instrument("duration_test", {}) do
        sleep 0.01
      end

      expect(events.first.duration).to be >= 10 # at least 10ms
    end
  end
end

RSpec.describe DeliveryBoy::NullInstrumenter do
  let(:instrumenter) { described_class.new }

  describe "#instrument" do
    it "executes the block without emitting events" do
      events = []
      subscription = ActiveSupport::Notifications.subscribe("null_test.delivery_boy") do |*args|
        events << args
      end

      result = instrumenter.instrument("null_test", {}) { "result" }

      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(events).to be_empty
      expect(result).to eq("result")
    end

    it "returns nil when no block is given" do
      result = instrumenter.instrument("no_block", {})
      expect(result).to be_nil
    end
  end
end
