require 'pg'
require 'thread'
require 'digest/md5'
require 'tusk/latch'

module Tusk
  module Observers
    module PG
      def self.extended klass
        super

        klass.instance_eval do
          @sub_lock       = Mutex.new
          @observer_state = false
          @subscribers    = {}
          @_listener      = nil
          @observing      = Latch.new
        end
      end

      attr_reader :subscribers

      def initialize *args
        super

        @sub_lock       = Mutex.new
        @observer_state = false
        @subscribers    = {}
        @_listener      = nil
        @observing      = Latch.new
      end

      def count_observers
        raise NotImplementedError
      end

      def delete_observers
        raise NotImplementedError
      end

      def changed?
        @observer_state
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
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end

      def add_observer object, func = :update
        subscribers.fetch(channel) { |k|
          Thread.new {
            start_listener
            connection.exec "LISTEN #{channel}"
          }
          subscribers[k] = {}
        }[object] = func
        @observing.await
      end

      def delete_observer o
        subscribers.fetch(channel, {}).delete o
      end

      private

      def start_listener
        return if @_listener

        @_listener = Thread.new(connection) do |conn|
          @observing.release

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
end
