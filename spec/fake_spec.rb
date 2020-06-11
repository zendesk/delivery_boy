require "spec_helper"

RSpec.describe DeliveryBoy::Fake do
  it "should match the public API" do
    aggregate_failures do
      DeliveryBoy::Instance.public_instance_methods(false).each do |public_method|
        expect(described_class.public_instance_methods).to include public_method
      end
    end
  end
end
