# DeliveryBoy

This library provides a dead easy way to start publishing messages to a Kafka cluster from your Ruby or Rails application!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'delivery_boy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install delivery_boy

## Usage

Once you've [installed the gem](#installation), and assuming your Kafka broker is running on localhost, you can simply start publishing messages to Kafka:

```ruby
# app/controllers/comments_controller.rb
class CommentsController < ApplicationController
  def create
    @comment = Comment.create!(params)

    # This will publish a JSON representation of the comment to the `comments` topic
    # in Kafka. Make sure to create the topic first, or this may fail.
    DeliveryBoy.deliver(comment.to_json, topic: "comments")
  end
end
```

The above example will block the server process until the message has been delivered. If you want deliveries to happen in the background in order to free up your server processes more quickly, call `#deliver_async` instead:

```ruby
# app/controllers/comments_controller.rb
class CommentsController < ApplicationController
  def show
    @comment = Comment.find(params[:id])

    event = {
      name: "comment_viewed",
      data: {
        comment_id: @comment.id,
        user_id: current_user.id
      }
    }

    # By delivering messages asynchronously you free up your server processes faster.
    DeliveryBoy.deliver_async(event.to_json, topic: "activity")
  end
end
```

In addition to improving response time, delivering messages asynchronously also protects your application against Kafka availability issues -- if messages cannot be delivered, they'll be buffered for later and retried automatically.

### Configuration

You configure DeliveryBoy either through a config file or by setting environment variables.

If you're using Rails, the fastest way to get started is to execute the following in your terminal:

```
$ bundle exec rails generate delivery_boy:install
```

This will create a config file at `config/delivery_boy.yml` with configurations for each of your Rails environments. Open that file in order to make changes.

The following configuration variables can be set:

##### `brokers`

A list of Kafka brokers that should be used to initialize the client. Defaults to just `localhost:9092` in development and test, but in production you need to pass a list of `hostname:port` strings.

##### `client_id`

This is how the client will identify itself to the Kafka brokers. Default is `delivery_boy`.

##### `ack_timeout`

A timeout executed by a broker when the client is sending messages to it. It defines the number of seconds the broker should wait for replicas to acknowledge the write before responding to the client with an error. As such, it relates to the `required_acks` setting. It should be set lower than `socket_timeout`.

##### `compression_codec`

The codec used to compress messages. Must be either `snappy` or `gzip`.

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#compression) for more information.

##### `compression_threshold`

The minimum number of messages that must be buffered before compression is attempted. By default only one message is required. Only relevant if `compression_codec` is set.

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#compression) for more information.

##### `connect_timeout`

The number of seconds to wait while connecting to a broker for the first time. When the Kafka library is initialized, it needs to connect to at least one host in `brokers` in order to discover the Kafka cluster. Each host is tried until there's one that works. Usually that means the first one, but if your entire cluster is down, or there's a network partition, you could wait up to `n * connect_timeout` seconds, where `n` is the number of hostnames in `brokers`.

##### `delivery_interval`

The number of seconds between background message deliveries. Default is 10 seconds. Disable timer-based background deliveries by setting this to 0.

##### `delivery_threshold`

The number of buffered messages that will trigger a background message delivery. Default is 100 messages. Disable buffer size based background deliveries by setting this to 0.

##### `max_buffer_bytesize`
##### `max_buffer_size`
##### `max_queue_size`

##### `max_retries`

The number of retries when attempting to deliver messages. The default is 2, so 3 attempts in total, but you can configure a higher or lower number.

##### `required_acks`

The number of Kafka replicas that must acknowledge messages before they're considered as successfully written. Default is _all_ replicas.

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#message-durability) for more information.

##### `retry_backoff`

The number of seconds to wait after a failed attempt to send messages to a Kafka broker before retrying. The `max_retries` setting defines the maximum number of retries to attempt, and so the total duration could be up to `max_retries * retry_backoff` seconds. The timeout can be arbitrarily long, and shouldn't be too short: if a broker goes down its partitions will be handed off to another broker, and that can take tens of seconds.

##### `socket_timeout`

Timeout when reading data from a socket connection to a Kafka broker. Must be larger than `ack_timeout` or you risk killing the socket before the broker has time to acknowledge your messages.

##### `ssl_ca_cert`

A PEM encoded CA cert, or an Array of PEM encoded CA certs, to use with an SSL connection.

##### `ssl_client_cert`

A PEM encoded client cert to use with an SSL connection. Must be used in combination with `ssl_client_cert_key`.

##### `ssl_client_cert_key`

A PEM encoded client cert key to use with an SSL connection. Must be used in combination with `ssl_client_cert`.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/dasch/delivery_boy).

## Copyright and license

Copyright 2017 Zendesk, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
