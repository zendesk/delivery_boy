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

Once you've [installed the gem](#installation), and assuming your Kafka broker is running on localhost, you can simply start publishing messages to Kafka directly from your Rails code:

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

A third method is to produce messages first (without delivering the messages to Kafka yet), and deliver them synchronously later.

```ruby
 # app/controllers/comments_controller.rb
 class CommentsController < ApplicationController
   def create
     @comment = Comment.create!(params)

     event = {
       name: "comment_created",
       data: {
         comment_id: @comment.id
         user_id: current_user.id
       }
     }

     # This will queue the two messages in the internal buffer.
     DeliveryBoy.produce(comment.to_json, topic: "comments")
     DeliveryBoy.produce(event.to_json, topic: "activity")

     # This will deliver all messages in the buffer to Kafka.
     # This call is blocking.
     DeliveryBoy.deliver_messages
   end
 end
```

The methods `deliver`, `deliver_async` and `produce` take the following options:

* `topic` – the Kafka topic that should be written to (required).
* `key` – the key that should be set on the Kafka message (optional).
* `partition` – a specific partition number that should be written to (optional).
* `partition_key` – a string that can be used to deterministically select the partition that should be written to (optional).

Regarding `partition` and `partition_key`: if none are specified, DeliveryBoy will pick a partition at random. If you want to ensure that e.g. all messages related to a user always get written to the same partition, you can pass the user id to `partition_key`. Don't use `partition` directly unless you know what you're doing, since it requires you to know exactly how many partitions each topic has, which can change and cause you pain and misery. Just use `partition_key` or let DeliveryBoy choose at random.

### Configuration

You configure DeliveryBoy in three different ways: in a YAML config file, in a Ruby config file, or by setting environment variables.

If you're using Rails, the fastest way to get started is to execute the following in your terminal:

```
$ bundle exec rails generate delivery_boy:install
```

This will create a config file at `config/delivery_boy.yml` with configurations for each of your Rails environments. Open that file in order to make changes.

Note that for all configuration variables, you can pass in an environment variable. These environment variables all take the form `DELIVERY_BOY_X`, where `X` is the upper-case configuration variable name, e.g. `DELIVERY_BOY_CLIENT_ID`.

You can also configure DeliveryBoy in Ruby if you prefer that. By default, the file `config/delivery_boy.rb` is loaded if present, but you can do this from anywhere – just call `DeliveryBoy.configure` like so:

```ruby
DeliveryBoy.configure do |config|
  config.client_id = "yolo"
  # ...
end
```

The following configuration variables can be set:

#### Basic

##### `brokers`

A list of Kafka brokers that should be used to initialize the client. Defaults to just `localhost:9092` in development and test, but in production you need to pass a list of `hostname:port` strings.

##### `client_id`

This is how the client will identify itself to the Kafka brokers. Default is `delivery_boy`.

##### `log_level`

The log level for the logger.

#### Message delivery

##### `delivery_interval`

The number of seconds between background message deliveries. Default is 10 seconds. Disable timer-based background deliveries by setting this to 0.

##### `delivery_threshold`

The number of buffered messages that will trigger a background message delivery. Default is 100 messages. Disable buffer size based background deliveries by setting this to 0.

##### `required_acks`

The number of Kafka replicas that must acknowledge messages before they're considered as successfully written. Default is _all_ replicas.

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#message-durability) for more information.

##### `ack_timeout`

A timeout executed by a broker when the client is sending messages to it. It defines the number of seconds the broker should wait for replicas to acknowledge the write before responding to the client with an error. As such, it relates to the `required_acks` setting. It should be set lower than `socket_timeout`.

##### `max_retries`

The number of retries when attempting to deliver messages. The default is 2, so 3 attempts in total, but you can configure a higher or lower number.

##### `retry_backoff`

The number of seconds to wait after a failed attempt to send messages to a Kafka broker before retrying. The `max_retries` setting defines the maximum number of retries to attempt, and so the total duration could be up to `max_retries * retry_backoff` seconds. The timeout can be arbitrarily long, and shouldn't be too short: if a broker goes down its partitions will be handed off to another broker, and that can take tens of seconds.

#### Compression

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#compression) for more information.

##### `compression_codec`

The codec used to compress messages. Must be either `snappy` or `gzip`.

##### `compression_threshold`

The minimum number of messages that must be buffered before compression is attempted. By default only one message is required. Only relevant if `compression_codec` is set.

#### Network

##### `connect_timeout`

The number of seconds to wait while connecting to a broker for the first time. When the Kafka library is initialized, it needs to connect to at least one host in `brokers` in order to discover the Kafka cluster. Each host is tried until there's one that works. Usually that means the first one, but if your entire cluster is down, or there's a network partition, you could wait up to `n * connect_timeout` seconds, where `n` is the number of hostnames in `brokers`.

##### `socket_timeout`

Timeout when reading data from a socket connection to a Kafka broker. Must be larger than `ack_timeout` or you risk killing the socket before the broker has time to acknowledge your messages.

#### Buffering

When using the asynhronous API, messages are buffered in a background thread and delivered to Kafka based on the configured delivery policy. Because of this, problems that hinder the delivery of messages can cause the buffer to grow. In order to avoid unlimited buffer growth that would risk affecting the host application, some limits are put in place. After the buffer reaches the maximum size allowed, calling `DeliveryBoy.deliver_async` will raise `Kafka::BufferOverflow`.

##### `max_buffer_bytesize`

The maximum number of bytes allowed in the buffer before new messages are rejected.

##### `max_buffer_size`

The maximum number of messages allowed in the buffer before new messages are rejected.

##### `max_queue_size`

The maximum number of messages allowed in the queue before new messages are rejected. The queue is used to ferry messages from the foreground threads of your application to the background thread that buffers and delivers messages. You typically only want to increase this number if you have a very high throughput of messages and the background thread can't keep up with spikes in throughput.

#### SSL Authentication and authorization

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#encryption-and-authentication-using-ssl) for more information.

##### `ssl_ca_cert`

A PEM encoded CA cert, or an Array of PEM encoded CA certs, to use with an SSL connection.

##### `ssl_ca_cert_file_path`

The path to a valid SSL certificate authority file.

##### `ssl_client_cert`

A PEM encoded client cert to use with an SSL connection. Must be used in combination with `ssl_client_cert_key`.

##### `ssl_client_cert_key`

A PEM encoded client cert key to use with an SSL connection. Must be used in combination with `ssl_client_cert`.

##### `ssl_client_cert_key_password`

The password required to read the ssl_client_cert_key. Must be used in combination with ssl_client_cert_key.

#### SASL Authentication and authorization

See [ruby-kafka](https://github.com/zendesk/ruby-kafka#authentication-using-sasl) for more information.

Use it through `GSSAPI`, `PLAIN` _or_ `OAUTHBEARER`.

##### `sasl_gssapi_principal`

The GSSAPI principal.

##### `sasl_gssapi_keytab`

Optional GSSAPI keytab.

##### `sasl_plain_authzid`

The authorization identity to use.

##### `sasl_plain_username`

The username used to authenticate.

##### `sasl_plain_password`

The password used to authenticate.

##### `sasl_oauth_token_provider`

A instance of a class which implements the `token` method.
As described in [ruby-kafka](https://github.com/zendesk/ruby-kafka/tree/c3e90bc355fad1e27b9af1048966ff08d3d5735b#oauthbearer)

```ruby
class TokenProvider
  def token
    "oauth-token"
  end
end

DeliveryBoy.configure do |config|
  config.sasl_oauth_token_provider = TokenProvider.new
  config.ssl_ca_certs_from_system = true
end
```
#### AWS MSK IAM Authentication and Authorization

##### sasl_aws_msk_iam_access_key_id

The AWS IAM access key. Required.

##### sasl_aws_msk_iam_secret_key_id

The AWS IAM secret access key. Required.

##### sasl_aws_msk_iam_aws_region

The AWS region. Required.

##### sasl_aws_msk_iam_session_token

The session token. This value can be optional.

###### Examples 

Using a role arn and web identity token to generate temporary credentials:

```ruby
require "aws-sdk-core"
require "delivery_boy"

role = Aws::AssumeRoleWebIdentityCredentials.new(
  role_arn: ENV["AWS_ROLE_ARN"],
  web_identity_token_file: ENV["AWS_WEB_IDENTITY_TOKEN_FILE"]
)

DeliveryBoy.configure do |c|
  c.sasl_aws_msk_iam_access_key_id = role.credentials.access_key_id
  c.sasl_aws_msk_iam_secret_key_id = role.credentials.secret_access_key
  c.sasl_aws_msk_iam_session_token = role.credentials.session_token
  c.sasl_aws_msk_iam_aws_region    = ENV["AWS_REGION"]
  c.ssl_ca_certs_from_system       = true
end
```

### Testing

DeliveryBoy provides a test mode out of the box. When this mode is enabled, messages will be stored in memory rather than being sent to Kafka. If you use RSpec, enabling test mode is as easy as adding this to your spec helper:

```ruby
# spec/spec_helper.rb
require "delivery_boy/rspec"
```

Now your application can use DeliveryBoy in tests without connecting to an actual Kafka cluster. Asserting that messages have been delivered is simple:

```ruby
describe PostsController do
  describe "#show" do
    it "emits an event to Kafka" do
      post = Post.create!(body: "hello")

      get :show, id: post.id

      # Use this API to extract all messages written to a Kafka topic.
      messages = DeliveryBoy.testing.messages_for("post_views")

      expect(messages.count).to eq 1

      # In addition to #value, you can also pull out #key and #partition_key.
      event = JSON.parse(messages.first.value)

      expect(event["post_id"]).to eq post.id
    end
  end
end
```

This takes care of clearing messages after each example, as well.

If you're not using RSpec, you can easily replicate the functionality yourself. Call `DeliveryBoy.test_mode!` at load time, and make sure that `DeliveryBoy.testing.clear` is called after each test.

### Instrumentation & monitoring

Since DeliveryBoy is just an opinionated API on top of ruby-kafka, you can use all the [instrumentation made available by that library](https://github.com/zendesk/ruby-kafka#instrumentation). You can also use the [existing monitoring solutions](https://github.com/zendesk/ruby-kafka#monitoring) that integrate with various monitoring services.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/zendesk/delivery_boy). Feel free to [join our Slack team](https://ruby-kafka-slack.herokuapp.com/) and ask how best to contribute!

## Support and Discussion

If you've discovered a bug, please file a [Github issue](https://github.com/zendesk/delivery_boy/issues/new), and make sure to include all the relevant information, including the version of DeliveryBoy, ruby-kafka, and Kafka that you're using.

If you have other questions, or would like to discuss best practises, how to contribute to the project, or any other ruby-kafka related topic, [join our Slack team](https://ruby-kafka-slack.herokuapp.com/)!

## Copyright and license

Copyright 2017 Zendesk, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
