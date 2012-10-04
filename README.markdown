# tusk

* http://github.com/tenderlove/tusk

## DESCRIPTION:

Tusk is a minimal pub / sub system with multiple observer strategies.
Tusk builds upon the Observer API from stdlib in order to provide a mostly
consistent API for building cross thread or process pub / sub systems.

Currently, Tusk supports Redis and PostgreSQL as message bus back ends.

## FEATURES/PROBLEMS:

* Send message across processes
* Supports Redis as a message bus
* Supports PostgreSQL as a message bus
* Supports DRb as a message bus

## SYNOPSIS:

Here is an in-memory observer example:

```ruby
require 'observer'

class Timer
  include Observable

  def tick
    changed
    notify_observers
  end
end

class Listener
  def update; puts "got update"; end
end

timer = Timer.new
timer.add_observer Listener.new
loop { timer.tick; sleep 1; }
```


The down side of this example is that the Listener cannot be in a different
process.  We can move the Listener to a different process by using the Redis
observable mixin and providing a redis connection:

```ruby
require 'tusk/observable/redis'
require 'redis'

class Timer
  include Tusk::Observable::Redis

  def tick
    changed
    notify_observers
  end

  def connection
    Thread.current[:redis] ||= ::Redis.new
  end
end

class Listener
  def update; puts "got update PID: #{$$}"; end
end

timer = Timer.new

fork {
  timer.add_observer Listener.new
  sleep
}

loop { timer.tick; sleep 1; }
```

PostgreSQL can also be used as the message bus:

```ruby
require 'tusk/observable/pg'
require 'pg'

class Timer
  include Tusk::Observable::PG

  def tick
    changed
    notify_observers
  end

  def connection
    Thread.current[:pg] ||= ::PG::Connection.new :dbname => 'postgres'
  end
end

class Listener
  def update; puts "got update PID: #{$$}"; end
end

timer = Timer.new

fork {
  timer.add_observer Listener.new
  sleep
}

loop { timer.tick; sleep 1; }
```

We can easily integrate Tusk with Active Record.  Here is a User model that
sends notifications when a user is created:

```ruby
require 'tusk/observable/pg'
class User < ActiveRecord::Base
  attr_accessible :name

  extend Tusk::Observable::PG

  # After users are created, notify the message bus
  after_create :notify_observers

  # Listeners will use the table name as the bus channel
  def self.channel
    table_name
  end

  private

  def notify_observers
    self.class.changed
    self.class.notify_observers
  end
end
```

The table name is used as the channel name where objects will listen.  Here is
a producer script:

```ruby
require 'user'
loop do
  User.create!(:name => 'testing')
  sleep 1
end
```

Our consumer adds an observer to the User class:

```ruby
require 'user'
class UserListener
  def initialize
    super
    @last_id = 0
  end

  def update
    users = User.where('id > ?', @last_id).sort_by(&:id)
    @last_id = users.last.id
    users.each { |u| p "user created: #{u.id}" }
  end
end

User.add_observer UserListener.new
# Put the main thread to sleep
sleep
```

Whenever a user gets created, our consumer listener will be notified.

## REQUIREMENTS:

* PostgreSQL or Redis

## INSTALL:

* gem install tusk

## LICENSE:

(The MIT License)

Copyright (c) 2012 Aaron Patterson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
