require "king_konf"

module DeliveryBoy
  class Config < KingKonf::Config
    prefix :delivery_boy

    integer :ack_timeout, default: 5
    integer :compression_threshold, default: 1
    integer :connect_timeout, default: 10
    integer :delivery_interval, default: 10
    integer :delivery_threshold, default: 100
    integer :max_buffer_bytesize, default: 10_000_000
    integer :max_buffer_size, default: 1000
    integer :max_queue_size, default: 1000
    integer :max_retries, default: 2
    integer :required_acks, default: -1
    integer :retry_backoff, default: 1
    integer :socket_timeout, default: 30
    string :client_id, default: "delivery_boy"
    string :compression_codec, default: nil
    string :ssl_ca_cert, default: nil
    string :ssl_client_cert, default: nil
    string :ssl_client_cert_key, default: nil
    list :brokers, items: :string, sep: ",", default: ["localhost:9092"]
  end
end
