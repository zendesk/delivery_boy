require "bundler/setup"
require "delivery_boy"
require "testcontainers/kafka"

RSpec.configure do |config|
  config.add_setting :container, default: nil

  config.before(:suite) do
    puts "Starting test containers"
    config.container = Testcontainers::KafkaContainer.new
    config.container.start
    kafka_container_health_check(config.container)
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

def kafka_container_health_check(container)
  command = %w[kafka-broker-api-versions --bootstrap-server localhost:9092]

  max_time = 10 # seconds
  end_time = Time.now + max_time

  loop do
    _stdout, _stderr, exit_code = container._container.exec(command)

    if exit_code != 0
      raise "Kafka is not ready" if Time.now > end_time
      print "·"
      sleep 0.5
    else
      puts
      return true
    end
  end
end
