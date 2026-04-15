require "spec_helper"
require "delivery_boy"

RSpec.describe DeliveryBoy::Instance do
  let(:logger) { Logger.new($stdout, level: ENV["DEBUG"] ? Logger::DEBUG : Logger::FATAL) }
  let(:config) do
    DeliveryBoy::Config.new.tap do |conf|
      conf.set(:brokers, [
        RSpec.configuration.container.connection_url
      ])
    end
  end
  let(:instance) { DeliveryBoy::Instance.new(config, logger) }

  # Upgrade note: There is no buffer anymore
  # describe "#buffer_size" do
  #   it "returns the number of messages in the buffer" do
  #     instance.produce("hello", topic: "greeting")
  #     instance.produce("world", topic: "greeting")

  #     expect(instance.buffer_size).to eq 2
  #   end
  # end

  describe "#deliver" do
    after do
      instance.shutdown
      Thread.current[:delivery_boy_sync_producer] = nil
    end

    it "delivers a message to Kafka" do
      instance.deliver("hello", topic: "greetings")
    end

    context "when transactional is set to true and transactional_id is missing" do
      before :each do
        config.transactional = true
      end

      it "raises an exception" do
        expect {
          instance.deliver("hello", topic: "greetings")
        }.to raise_error("transactional_id must be set")
      end
    end
  end

  describe "#deliver_async" do
    it "delivers a message to Kafka asynchronously" do
      instance.deliver("hello", topic: "greetings")
    end
  end

  describe "#produce and #deliver_messages" do
    it "produces and delivers a message to kafka" do
      instance.produce("hello", topic: "greeting")
      instance.deliver_messages
    end
  end

  describe "SASL configuration mapping" do
    describe "#sasl_options" do
      context "when no SASL is configured" do
        it "returns empty hash" do
          options = instance.send(:sasl_options)
          expect(options).to eq({})
        end
      end

      context "with GSSAPI mechanism" do
        before do
          config.sasl_mechanism = "GSSAPI"
          config.sasl_gssapi_principal = "kafka/hostname@REALM"
          config.sasl_gssapi_keytab = "/path/to/keytab"
        end

        it "maps GSSAPI configuration correctly" do
          options = instance.send(:sasl_options)

          expect(options["sasl.mechanism"]).to eq("GSSAPI")
          expect(options["sasl.kerberos.principal"]).to eq("kafka/hostname@REALM")
          expect(options["sasl.kerberos.keytab"]).to eq("/path/to/keytab")
        end
      end

      context "with PLAIN mechanism" do
        context "using new config options" do
          before do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = "new_user"
            config.sasl_password = "new_pass"
          end

          it "maps new config to librdkafka format" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("PLAIN")
            expect(options["sasl.username"]).to eq("new_user")
            expect(options["sasl.password"]).to eq("new_pass")
          end
        end

        context "using old config options" do
          before do
            config.sasl_mechanism = "PLAIN"
            config.sasl_plain_username = "old_user"
            config.sasl_plain_password = "old_pass"
          end

          it "supports old config options" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("PLAIN")
            expect(options["sasl.username"]).to eq("old_user")
            expect(options["sasl.password"]).to eq("old_pass")
          end
        end

        context "with sasl_plain_authzid set" do
          before do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = "user"
            config.sasl_password = "pass"
            config.sasl_plain_authzid = "authzid"
          end

          it "logs a warning about unsupported authzid" do
            expect(logger).to receive(:warn).with(/sasl_plain_authzid is not supported/)
            instance.send(:sasl_options)
          end
        end

        context "when both old and new config are set" do
          before do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = "new_user"
            config.sasl_plain_username = "old_user"
            config.sasl_password = "new_pass"
            config.sasl_plain_password = "old_pass"
          end

          it "prioritizes new config over old config" do
            options = instance.send(:sasl_options)

            expect(options["sasl.username"]).to eq("new_user")
            expect(options["sasl.password"]).to eq("new_pass")
          end
        end

        context "with missing credentials" do
          it "raises error when username is missing" do
            config.sasl_mechanism = "PLAIN"
            config.sasl_password = "pass"

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /PLAIN authentication requires sasl_username and sasl_password/
            )
          end

          it "raises error when password is missing" do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = "user"

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /PLAIN authentication requires sasl_username and sasl_password/
            )
          end

          it "raises error when username is empty string" do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = ""
            config.sasl_password = "pass"

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /PLAIN authentication requires sasl_username and sasl_password/
            )
          end

          it "raises error when password is empty string" do
            config.sasl_mechanism = "PLAIN"
            config.sasl_username = "user"
            config.sasl_password = ""

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /PLAIN authentication requires sasl_username and sasl_password/
            )
          end
        end

        context "with case-insensitive mechanism name" do
          before do
            config.sasl_mechanism = "plain"  # lowercase
            config.sasl_username = "user"
            config.sasl_password = "pass"
          end

          it "handles lowercase mechanism names" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("PLAIN")
            expect(options["sasl.username"]).to eq("user")
          end
        end
      end

      context "with SCRAM-SHA-256 mechanism" do
        context "using new config options" do
          before do
            config.sasl_mechanism = "SCRAM-SHA-256"
            config.sasl_username = "new_user"
            config.sasl_password = "new_pass"
          end

          it "maps SCRAM-SHA-256 correctly" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("SCRAM-SHA-256")
            expect(options["sasl.username"]).to eq("new_user")
            expect(options["sasl.password"]).to eq("new_pass")
          end
        end

        context "using old config options" do
          before do
            config.sasl_mechanism = "SCRAM-SHA-256"
            config.sasl_scram_username = "old_user"
            config.sasl_scram_password = "old_pass"
          end

          it "supports old config options" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("SCRAM-SHA-256")
            expect(options["sasl.username"]).to eq("old_user")
            expect(options["sasl.password"]).to eq("old_pass")
          end
        end

        context "with missing credentials" do
          it "raises error when credentials are missing" do
            config.sasl_mechanism = "SCRAM-SHA-256"

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /SCRAM authentication requires sasl_username and sasl_password/
            )
          end

          it "raises error when credentials are empty strings" do
            config.sasl_mechanism = "SCRAM-SHA-256"
            config.sasl_username = ""
            config.sasl_password = ""

            expect { instance.send(:sasl_options) }.to raise_error(
              DeliveryBoy::ConfigError,
              /SCRAM authentication requires sasl_username and sasl_password/
            )
          end
        end

        context "with case-insensitive mechanism name" do
          before do
            config.sasl_mechanism = "scram-sha-256"  # lowercase
            config.sasl_username = "user"
            config.sasl_password = "pass"
          end

          it "handles lowercase mechanism names" do
            options = instance.send(:sasl_options)

            expect(options["sasl.mechanism"]).to eq("SCRAM-SHA-256")
            expect(options["sasl.username"]).to eq("user")
          end
        end
      end

      context "with SCRAM-SHA-512 mechanism" do
        before do
          config.sasl_mechanism = "SCRAM-SHA-512"
          config.sasl_username = "user"
          config.sasl_password = "pass"
        end

        it "maps SCRAM-SHA-512 correctly" do
          options = instance.send(:sasl_options)

          expect(options["sasl.mechanism"]).to eq("SCRAM-SHA-512")
          expect(options["sasl.username"]).to eq("user")
          expect(options["sasl.password"]).to eq("pass")
        end
      end

      context "with OAUTHBEARER mechanism" do
        before do
          config.sasl_mechanism = "OAUTHBEARER"
        end

        it "raises error when OIDC config is missing" do
          expect { instance.send(:sasl_options) }.to raise_error(
            DeliveryBoy::ConfigError,
            /OAUTHBEARER requires OIDC configuration/
          )
        end

        it "raises error when legacy token provider is used" do
          config.sasl_oauth_token_provider = Object.new
          expect { instance.send(:sasl_options) }.to raise_error(
            DeliveryBoy::ConfigError,
            /sasl_oauth_token_provider is no longer supported/
          )
        end

        context "with OIDC configuration" do
          before do
            config.sasl_oauthbearer_method = "oidc"
            config.sasl_oauthbearer_client_id = "my-client"
            config.sasl_oauthbearer_client_secret = "my-secret"
            config.sasl_oauthbearer_token_endpoint_url = "https://auth.example.com/token"
          end

          it "returns OIDC options" do
            options = instance.send(:sasl_options)
            expect(options["sasl.mechanism"]).to eq("OAUTHBEARER")
            expect(options["sasl.oauthbearer.method"]).to eq("oidc")
            expect(options["sasl.oauthbearer.client.id"]).to eq("my-client")
            expect(options["sasl.oauthbearer.client.secret"]).to eq("my-secret")
            expect(options["sasl.oauthbearer.token.endpoint.url"]).to eq("https://auth.example.com/token")
          end

          it "includes optional scope when set" do
            config.sasl_oauthbearer_scope = "kafka"
            options = instance.send(:sasl_options)
            expect(options["sasl.oauthbearer.scope"]).to eq("kafka")
          end
        end
      end

      context "with AWS MSK IAM configuration" do
        before do
          config.sasl_mechanism = "PLAIN"
          config.sasl_aws_msk_iam_access_key_id = "key"
        end

        it "raises helpful error" do
          expect { instance.send(:sasl_options) }.to raise_error(
            DeliveryBoy::ConfigError,
            /AWS MSK IAM.*not supported/
          )
        end
      end

      context "with unknown SASL mechanism" do
        before do
          config.sasl_mechanism = "UNKNOWN"
        end

        it "logs a warning" do
          expect(logger).to receive(:warn).with(/Unknown SASL mechanism: UNKNOWN/)
          instance.send(:sasl_options)
        end
      end
    end

    describe "#security_protocol" do
      it "returns PLAINTEXT when no SSL or SASL is configured" do
        expect(instance.send(:security_protocol)).to eq("PLAINTEXT")
      end

      it "returns SSL when only SSL is configured" do
        config.ssl_ca_cert_file_path = "/path/to/ca.pem"
        expect(instance.send(:security_protocol)).to eq("SSL")
      end

      it "returns SASL_PLAINTEXT when only SASL is configured" do
        config.sasl_mechanism = "PLAIN"
        config.sasl_username = "user"
        expect(instance.send(:security_protocol)).to eq("SASL_PLAINTEXT")
      end

      it "returns SASL_SSL when both SASL and SSL are configured" do
        config.sasl_mechanism = "PLAIN"
        config.sasl_username = "user"
        config.ssl_ca_cert_file_path = "/path/to/ca.pem"
        expect(instance.send(:security_protocol)).to eq("SASL_SSL")
      end

      it "returns SASL_PLAINTEXT for GSSAPI" do
        config.sasl_gssapi_principal = "kafka/hostname@REALM"
        expect(instance.send(:security_protocol)).to eq("SASL_PLAINTEXT")
      end
    end
  end
end
