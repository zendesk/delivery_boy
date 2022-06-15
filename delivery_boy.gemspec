# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "delivery_boy/version"

Gem::Specification.new do |spec|
  spec.name          = "delivery_boy"
  spec.version       = DeliveryBoy::VERSION
  spec.authors       = ["Daniel Schierbeck"]
  spec.email         = ["daniel.schierbeck@gmail.com"]

  spec.summary       = "A simple way to produce messages to Kafka from Ruby applications"
  spec.description   = "A simple way to produce messages to Kafka from Ruby applications"
  spec.homepage      = "https://github.com/zendesk/delivery_boy"
  spec.license       = "Apache License Version 2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.require_paths = ["lib"]

  # spec.add_runtime_dependency "ruby-kafka", "~> 1.0"
  spec.add_runtime_dependency "king_konf", "~> 1.0"
  spec.add_runtime_dependency "rdkafka", "> 0.11"

  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
