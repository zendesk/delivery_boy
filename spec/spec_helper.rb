require "bundler/setup"
require "delivery_boy"
require "testcontainers/kafka"

RSpec.configure do |config|
  config.add_setting :container, default: nil

  config.before(:suite) do
    puts "Starting test containers"
    config.container = Testcontainers::KafkaContainer.new(
      healthcheck: {
        test: ["kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"],
        interval: 0.2,
        timeout: 1,
        retries: 20
      }
    )
    config.container.start
    config.container.wait_for_healthcheck
  end

  config.after(:suite) do
    puts
    puts "Shutting down test containers"
    config.container.stop if config.container&.running?
    config.container.remove if config.container&.exists?
  end

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
