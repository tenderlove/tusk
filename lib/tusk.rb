require 'pg'
require 'thread'
require 'monitor'
require 'mutex_m'

module Tusk
  VERSION = '1.0.0'

  module Observer
    def self.extended klass
      super

      klass.instance_eval do
        @sub_lock       = Mutex.new
        @observer_state = false
        @subscribers    = {}
        @_listener      = nil
      end
    end

    attr_reader :subscribers

    def initialize *args
      super

      @sub_lock       = Mutex.new
      @observer_state = false
      @subscribers    = {}
      @_listener      = nil
    end

    def changed state = true
      @observer_state = state
    end

    def notify_observers
      return unless @observer_state
      connection.exec "NOTIFY #{channel}"
      @observer_state = false
    end

    def channel
      "#{self.class.name}#{object_id}".downcase
    end

    def add_observer object, func = :update
      subscribers.fetch(channel) { |k|
        Thread.new {
          start_listener
          connection.exec "LISTEN #{channel}"
        }
        subscribers[k] = {}
      }[object] = func
    end

    private

    def start_listener
      return if @_listener

      @_listener = Thread.new(connection) do |conn|
        loop do
          conn.wait_for_notify do |event, pid|
            subscribers.fetch(event, []).dup.each do |listener, func|
              listener.send func
            end
          end
        end
      end
    end
  end
end

class Ticker
  include Tusk::Observer

  def tick
    changed
    notify_observers
  end

  def connection
    Thread.current[:conn] ||= PG::Connection.new :dbname => 'postgres'
  end
end

if $0 == __FILE__
  ticker = Ticker.new

  Thread.new {
    queue = Queue.new

    def queue.update
      push :msg
    end

    ticker.add_observer queue

    while t = queue.pop
      p t
    end
  }

  Thread.new {
    sleep 3
    queue = Queue.new

    def queue.update
      push :omg
    end

    ticker.add_observer queue

    while t = queue.pop
      p t
    end
  }

  loop do
    ticker.tick
    puts "tick"
    sleep 1
  end
end
