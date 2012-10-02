require 'securerandom'
require 'thread'
require 'tusk/latch'

module Tusk
  module Observable
    ###
    # An observer implementation for Redis.  This module requires that
    # your class implement a `connection` method that returns a redis
    # connection that this module can use.
    #
    # This observer works across processes.
    #
    # Example:
    #
    #     require 'redis'
    #     require 'tusk/observable/redis'
    #     
    #     class Timer
    #       include Tusk::Observable::Redis
    #     
    #       def tick
    #         changed
    #         notify_observers
    #       end
    #     
    #       def connection
    #         Thread.current[:conn] ||= ::Redis.new
    #       end
    #     end
    #     
    #     class Listener
    #       def update
    #         puts "got update"
    #       end
    #     end
    #     
    #     timer = Timer.new
    #     
    #     fork do
    #       timer.add_observer Listener.new
    #       sleep # put the process to sleep so it doesn't exit
    #     end
    #     
    #     loop do
    #       timer.tick
    #       sleep 1
    #     end
    module Redis
      def self.extended klass
        super

        klass.instance_eval do
          @sub_lock        = Mutex.new
          @observer_state  = false
          @subscribers     = {}
          @_listener       = nil
          @control_channel = SecureRandom.hex
        end
      end

      attr_reader :subscribers, :control_channel

      def initialize *args
        super

        @sub_lock        = Mutex.new
        @observer_state  = false
        @subscribers     = {}
        @_listener       = nil
        @control_channel = SecureRandom.hex
      end

      # Returns the number of observers associated with this object *in the
      # current process*.  If the object is observed across multiple processes,
      # the returned count will not reflect the other processes.
      def count_observers
        @sub_lock.synchronize { subscribers.fetch(channel, {}).length }
      end

      # Remove all observers associated with this object *in the current
      # process*. This method will not impact observers of this object in
      # other processes.
      def delete_observers
        @sub_lock.synchronize { subscribers.delete channel }
        connection.publish control_channel, 'quit'
      end

      # Returns true if this object's state has been changed since the last
      # call to #notify_observers.
      def changed?
        @observer_state
      end

      # Set the changed state of this object.  Notifications will be sent only
      # if the changed +state+ is a truthy object.
      def changed state = true
        @observer_state = state
      end

      # If this object's #changed? state is true, this method will notify
      # observing objects.
      def notify_observers(*args)
        return unless changed?
        connection.publish channel, Marshal.dump(args)
        changed false
      end

      # Add +observer+ as an observer to this object.  The +object+ will
      # receive a notification when #changed? returns true and #notify_observers
      # is called.
      #
      # +func+ method is called on +object+ when notifications are sent.
      def add_observer object, func = :update
        observer_set = Latch.new
        observing    = Latch.new

        @sub_lock.synchronize do
          observing.release if subscribers.key? channel

          subscribers.fetch(channel) { |k|
            Thread.new {
              observer_set.await
              start_listener(observing)
            }
            subscribers[k] = {}
          }[object] = func
        end

        observer_set.release
        observing.await
      end

      # Remove +observer+ so that it will no longer receive notifications.
      def delete_observer o
        @sub_lock.synchronize do
          subscribers.fetch(channel, {}).delete o
          if subscribers.fetch(channel,{}).empty?
            subscribers.delete channel
            connection.publish control_channel, 'quit'
          end
        end
      end

      private

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end

      def payload_coder
        Marshal
      end

      def start_listener latch
        connection.subscribe(channel, control_channel) do |on|
          on.subscribe { |c| latch.release }

          on.message do |c, message|
            if c == control_channel && message == 'quit'
              connection.unsubscribe
            else
              @sub_lock.synchronize do
                subscribers.fetch(c, {}).each do |object,m|
                  object.send m, *payload_coder.load(message)
                end
              end
            end
          end
        end
      end
    end
  end
end
