# frozen_string_literal: true

module DeliveryBoy
  class Instrumenter
    NAMESPACE = "delivery_boy"

    def initialize(default_payload: {})
      require "active_support/notifications"
      @default_payload = default_payload
    end

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument(
        "#{event_name}.#{NAMESPACE}",
        @default_payload.merge(payload),
        &block
      )
    end
  end

  class NullInstrumenter
    def instrument(*, &block)
      block&.call
    end
  end
end
