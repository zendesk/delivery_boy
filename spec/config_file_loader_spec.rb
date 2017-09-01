require "delivery_boy/config"
require "delivery_boy/config_file_loader"

RSpec.describe DeliveryBoy::ConfigFileLoader do
  let(:config) { DeliveryBoy::Config.new }
  let(:loader) { described_class.new(config) }

  it "loads configuration from a YAML file" do
    loader.load_file("spec/fixtures/config.yml", "production")

    expect(config.client_id).to eq "cthulhu"
  end
end
