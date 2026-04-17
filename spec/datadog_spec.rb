# frozen_string_literal: true

require "spec_helper"
require "active_support"
require "delivery_boy/datadog"

RSpec.describe DeliveryBoy::Datadog do
  let(:statsd) { instance_double(Datadog::Statsd) }

  before do
    allow(statsd).to receive(:increment)
    allow(statsd).to receive(:histogram)
    allow(statsd).to receive(:count)
    allow(statsd).to receive(:timing)
    allow(statsd).to receive(:gauge)
    allow(statsd).to receive(:close)

    DeliveryBoy::Datadog.statsd = statsd
  end

  after do
    DeliveryBoy::Datadog.instance_variable_set(:@statsd, nil)
    DeliveryBoy::Datadog.instance_variable_set(:@host, nil)
    DeliveryBoy::Datadog.instance_variable_set(:@port, nil)
    DeliveryBoy::Datadog.instance_variable_set(:@namespace, nil)
    DeliveryBoy::Datadog.instance_variable_set(:@tags, nil)
  end

  describe ".configure" do
    it "yields self for configuration" do
      DeliveryBoy::Datadog.configure do |config|
        config.host = "custom-host"
        config.port = 9999
        config.namespace = "custom-namespace"
        config.tags = ["env:test"]
      end

      expect(DeliveryBoy::Datadog.host).to eq("custom-host")
      expect(DeliveryBoy::Datadog.port).to eq(9999)
      expect(DeliveryBoy::Datadog.namespace).to eq("custom-namespace")
      expect(DeliveryBoy::Datadog.tags).to eq(["env:test"])
    end
  end

  describe "ProducerSubscriber" do
    describe "produce_message event" do
      it "emits producer metrics on success" do
        ActiveSupport::Notifications.instrument("produce_message.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 100,
          buffer_size: 5
        })

        expect(statsd).to have_received(:increment).with("producer.produce.messages", tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:histogram).with("producer.produce.message_size", 100, tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:count).with("producer.produce.message_size.sum", 100, tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:histogram).with("producer.buffer.size", 5, tags: ["client:test-client", "topic:test-topic"])
      end

      it "emits error metric on exception" do
        ActiveSupport::Notifications.instrument("produce_message.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 100,
          buffer_size: 5,
          exception: [StandardError, "test error"]
        })

        expect(statsd).to have_received(:increment).with("producer.produce.errors", tags: ["client:test-client", "topic:test-topic"])
      end
    end

    describe "deliver event" do
      it "emits delivery metrics on success" do
        ActiveSupport::Notifications.instrument("deliver.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 200
        })

        expect(statsd).to have_received(:increment).with("producer.produce.messages", tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:histogram).with("producer.produce.message_size", 200, tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:timing).with("producer.deliver.latency", anything, tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:count).with("producer.deliver.messages", 1, tags: ["client:test-client", "topic:test-topic"])
      end

      it "emits error metric on exception" do
        ActiveSupport::Notifications.instrument("deliver.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 200,
          exception: [StandardError, "test error"]
        })

        expect(statsd).to have_received(:increment).with("producer.deliver.errors", tags: ["client:test-client", "topic:test-topic"])
      end
    end

    describe "deliver_messages event" do
      it "emits batch delivery metrics" do
        ActiveSupport::Notifications.instrument("deliver_messages.delivery_boy", {
          client_id: "test-client",
          delivered_message_count: 10
        })

        expect(statsd).to have_received(:timing).with("producer.deliver.latency", anything, tags: ["client:test-client"])
        expect(statsd).to have_received(:count).with("producer.deliver.messages", 10, tags: ["client:test-client"])
      end
    end

    describe "deliver_async event" do
      it "emits async producer metrics on success" do
        ActiveSupport::Notifications.instrument("deliver_async.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 150,
          queue_size: 3
        })

        expect(statsd).to have_received(:increment).with("producer.produce.messages", tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:histogram).with("producer.produce.message_size", 150, tags: ["client:test-client", "topic:test-topic"])
        expect(statsd).to have_received(:histogram).with("async_producer.queue.size", 3, tags: ["client:test-client", "topic:test-topic"])
      end

      it "emits error metric on exception" do
        ActiveSupport::Notifications.instrument("deliver_async.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic",
          message_size: 150,
          queue_size: 3,
          exception: [StandardError, "test error"]
        })

        expect(statsd).to have_received(:increment).with("async_producer.produce.errors", tags: ["client:test-client", "topic:test-topic"])
      end
    end

    describe "ack_message event" do
      it "emits acknowledgment metric" do
        ActiveSupport::Notifications.instrument("ack_message.delivery_boy", {
          client_id: "test-client",
          topic: "test-topic"
        })

        expect(statsd).to have_received(:increment).with("producer.ack.messages", tags: ["client:test-client", "topic:test-topic"])
      end
    end

    describe "delivery_error event" do
      it "emits error metric" do
        ActiveSupport::Notifications.instrument("delivery_error.delivery_boy", {
          client_id: "test-client"
        })

        expect(statsd).to have_received(:increment).with("producer.ack.errors", tags: ["client:test-client"])
      end
    end
  end
end
