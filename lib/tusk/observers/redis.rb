require 'securerandom'
require 'thread'

module Tusk
  module Observers
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

      def count_observers
        @sub_lock.synchronize { subscribers.fetch(channel, {}).length }
      end

      def delete_observers
        @sub_lock.synchronize { subscribers.delete channel }
        connection.publish control_channel, 'quit'
      end

      def changed?
        @observer_state
      end

      def changed state = true
        @observer_state = state
      end

      def notify_observers
        return unless @observer_state
        connection.publish channel, nil
        @observer_state = false
      end

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

      def connection
        raise NotImplementedError, "you must implement the `connection` method for the redis obsever"
      end

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
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
                  object.send m
                end
              end
            end
          end
        end
      end
    end
  end
end
