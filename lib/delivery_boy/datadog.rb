# frozen_string_literal: true

begin
  require "datadog/statsd"
rescue LoadError
  warn "In order to report Kafka client metrics to Datadog you need to install the `dogstatsd-ruby` gem."
  raise
end

require "active_support/subscriber"

module DeliveryBoy
  # Reports operational metrics to a Datadog agent using the Statsd protocol.
  #
  #     require "delivery_boy/datadog"
  #
  #     # Default is "ruby_kafka" (kept for backward compatibility).
  #     DeliveryBoy::Datadog.namespace = "custom-namespace"
  #
  #     # Default is "127.0.0.1".
  #     DeliveryBoy::Datadog.host = "statsd.something.com"
  #
  #     # Default is 8125.
  #     DeliveryBoy::Datadog.port = 1234
  #
  module Datadog
    STATSD_NAMESPACE = "ruby_kafka"

    class << self
      attr_reader :host, :port, :socket_path

      def configure
        yield self
      end

      def statsd
        @statsd ||= if socket_path
          ::Datadog::Statsd.new(socket_path: socket_path, namespace: namespace, tags: tags)
        else
          ::Datadog::Statsd.new(host, port, namespace: namespace, tags: tags)
        end
      end

      def statsd=(statsd)
        clear
        @statsd = statsd
      end

      def host=(host)
        @host = host
        clear
      end

      def port=(port)
        @port = port
        clear
      end

      def socket_path=(socket_path)
        @socket_path = socket_path
        clear
      end

      def namespace
        @namespace ||= STATSD_NAMESPACE
      end

      def namespace=(namespace)
        @namespace = namespace
        clear
      end

      def tags
        @tags ||= []
      end

      def tags=(tags)
        @tags = tags
        clear
      end

      def close
        @statsd&.close
      end

      private

      def clear
        close
        @statsd = nil
      end
    end

    class StatsdSubscriber < ActiveSupport::Subscriber
      private

      %w[increment histogram count timing gauge].each do |type|
        define_method(type) do |*args, **kwargs|
          emit(type, *args, **kwargs)
        end
      end

      def emit(type, *args, tags: {})
        tags = tags.map { |k, v| "#{k}:#{v}" }.to_a
        DeliveryBoy::Datadog.statsd.send(type, *args, tags: tags)
      end
    end

    class ProducerSubscriber < StatsdSubscriber
      def produce_message(event)
        client = event.payload.fetch(:client_id)
        topic = event.payload.fetch(:topic)
        message_size = event.payload.fetch(:message_size)
        buffer_size = event.payload.fetch(:buffer_size)

        tags = {client: client, topic: topic}

        if event.payload.key?(:exception)
          increment("producer.produce.errors", tags: tags)
        else
          increment("producer.produce.messages", tags: tags)
          histogram("producer.produce.message_size", message_size, tags: tags)
          count("producer.produce.message_size.sum", message_size, tags: tags)
          histogram("producer.buffer.size", buffer_size, tags: tags)
        end
      end

      def deliver_messages(event)
        client = event.payload.fetch(:client_id)
        message_count = event.payload.fetch(:delivered_message_count)

        tags = {client: client}

        increment("producer.deliver.errors", tags: tags) if event.payload.key?(:exception)
        timing("producer.deliver.latency", event.duration, tags: tags)
        count("producer.deliver.messages", message_count, tags: tags)
      end

      def deliver(event)
        client = event.payload.fetch(:client_id)
        topic = event.payload.fetch(:topic)
        message_size = event.payload.fetch(:message_size)

        tags = {client: client, topic: topic}

        if event.payload.key?(:exception)
          increment("producer.deliver.errors", tags: tags)
        else
          increment("producer.produce.messages", tags: tags)
          histogram("producer.produce.message_size", message_size, tags: tags)
          count("producer.produce.message_size.sum", message_size, tags: tags)
          timing("producer.deliver.latency", event.duration, tags: tags)
          count("producer.deliver.messages", 1, tags: tags)
        end
      end

      def deliver_async(event)
        client = event.payload.fetch(:client_id)
        topic = event.payload.fetch(:topic)
        message_size = event.payload.fetch(:message_size)
        queue_size = event.payload.fetch(:queue_size, 0)

        tags = {client: client, topic: topic}

        if event.payload.key?(:exception)
          increment("async_producer.produce.errors", tags: tags)
        else
          increment("producer.produce.messages", tags: tags)
          histogram("producer.produce.message_size", message_size, tags: tags)
          count("producer.produce.message_size.sum", message_size, tags: tags)
          histogram("async_producer.queue.size", queue_size, tags: tags)
        end
      end

      def ack_message(event)
        tags = {
          client: event.payload.fetch(:client_id),
          topic: event.payload.fetch(:topic)
        }

        increment("producer.ack.messages", tags: tags)
      end

      def delivery_error(event)
        tags = {client: event.payload.fetch(:client_id)}
        increment("producer.ack.errors", tags: tags)
      end

      attach_to "delivery_boy"
    end
  end
end
