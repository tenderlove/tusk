require 'thread'
require 'digest/md5'
require 'tusk/latch'

module Tusk
  module Observers
    ###
    # An observer implementation for PostgreSQL.  This module requires that
    # your class implement a `connection` method that returns a database
    # connection that this module can use.
    #
    # This observer works across processes.
    #
    # Example:
    #
    #     require 'pg'
    #     require 'tusk/observers/pg'
    #     
    #     class Timer
    #       include Tusk::Observers::PG
    #     
    #       def tick
    #         changed
    #         notify_observers
    #       end
    #     
    #       def connection
    #         Thread.current[:conn] ||= ::PG::Connection.new :dbname => 'postgres'
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

      def add_observer object, func = :update
        @sub_lock.synchronize do
          subscribers.fetch(channel) { |k|
            Thread.new {
              start_listener
              connection.exec "LISTEN #{channel}"
              observing.release
            }
            subscribers[k] = {}
          }[object] = func
        end

        @observing.await
      end

      def delete_observer o
        @sub_lock.synchronize do
          subscribers.fetch(channel, {}).delete o
        end
      end

      private

      def connection
        raise NotImplementedError, "you must implement the `connection` method for the PG obsever"
      end

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end

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
