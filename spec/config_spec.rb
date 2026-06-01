require "bundler/setup"
require "delivery_boy"

RSpec.describe DeliveryBoy::Config do
  let(:config) { described_class.new }

  describe "SASL configuration" do
    describe "#sasl_enabled?" do
      it "returns false when sasl_mechanism is nil" do
        config.sasl_mechanism = nil
        expect(config.sasl_enabled?).to be false
      end

      it "returns false when sasl_mechanism is empty" do
        config.sasl_mechanism = ""
        expect(config.sasl_enabled?).to be false
      end

      it "returns false for GSSAPI mechanism" do
        config.sasl_mechanism = "GSSAPI"
        expect(config.sasl_enabled?).to be false
      end

      it "returns true for PLAIN mechanism" do
        config.sasl_mechanism = "PLAIN"
        expect(config.sasl_enabled?).to be true
      end

      it "returns true for SCRAM-SHA-256 mechanism" do
        config.sasl_mechanism = "SCRAM-SHA-256"
        expect(config.sasl_enabled?).to be true
      end

      it "returns true for SCRAM-SHA-512 mechanism" do
        config.sasl_mechanism = "SCRAM-SHA-512"
        expect(config.sasl_enabled?).to be true
      end
    end

    describe "#validate_aws_msk_iam!" do
      it "raises error when sasl_aws_msk_iam_access_key_id is set" do
        config.sasl_aws_msk_iam_access_key_id = "key"

        expect { config.validate_aws_msk_iam! }.to raise_error(
          DeliveryBoy::ConfigError,
          /AWS MSK IAM authentication is not supported/
        )
      end

      it "raises error when sasl_aws_msk_iam_secret_key_id is set" do
        config.sasl_aws_msk_iam_secret_key_id = "secret"

        expect { config.validate_aws_msk_iam! }.to raise_error(
          DeliveryBoy::ConfigError,
          /AWS MSK IAM authentication is not supported/
        )
      end

      it "raises error when sasl_aws_msk_iam_aws_region is set" do
        config.sasl_aws_msk_iam_aws_region = "us-east-1"

        expect { config.validate_aws_msk_iam! }.to raise_error(
          DeliveryBoy::ConfigError,
          /AWS MSK IAM authentication is not supported/
        )
      end

      it "does not raise error when no AWS MSK IAM config is set" do
        expect { config.validate_aws_msk_iam! }.not_to raise_error
      end
    end

    describe "new consolidated SASL options" do
      it "allows setting sasl_username" do
        config.sasl_username = "test_user"
        expect(config.sasl_username).to eq("test_user")
      end

      it "allows setting sasl_password" do
        config.sasl_password = "test_pass"
        expect(config.sasl_password).to eq("test_pass")
      end
    end
  end
end
