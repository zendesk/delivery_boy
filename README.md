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

* `brokers` – A list of Kafka brokers that should be used to initialize the client. Defaults to just `localhost:9092` in development and test, but in production you need to pass a list of `hostname:port` strings.
* `client_id` – This is how the client will identify itself to the Kafka brokers. Useful for debugging.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/dasch/delivery_boy).

## Copyright and license

Copyright 2017 Zendesk, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
