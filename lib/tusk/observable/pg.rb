require 'thread'
require 'digest/md5'
require 'tusk/latch'

module Tusk
  module Observable
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
    #     require 'tusk/observable/pg'
    #     
    #     class Timer
    #       include Tusk::Observable::PG
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

        unwrap(connection).exec "NOTIFY #{channel}, #{args}"

        changed false
      end

      # Add +observer+ as an observer to this object.  The +object+ will
      # receive a notification when #changed? returns true and #notify_observers
      # is called.
      #
      # +func+ method is called on +object+ when notifications are sent.
      def add_observer object, func = :update
        @sub_lock.synchronize do
          subscribers.fetch(channel) { |k|
            Thread.new {
              start_listener
              unwrap(connection).exec "LISTEN #{channel}"
              @observing.release
            }
            subscribers[k] = {}
          }[object] = func
        end

        @observing.await
      end

      # Remove +observer+ so that it will no longer receive notifications.
      def delete_observer o
        @sub_lock.synchronize do
          subscribers.fetch(channel, {}).delete o
        end
      end

      private

      def unwrap conn
        if conn.respond_to? :exec
          conn
        else
          # Yes, I am a terrible person.  This pulls
          # the connection out of AR connections.
          conn.instance_eval { @connection }
        end
      end

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end

      def start_listener
        return if @_listener

        @_listener = Thread.new(unwrap(connection)) do |conn|
          @observing.release

          loop do
            conn.wait_for_notify do |event, pid, payload|
              subscribers.fetch(event, []).dup.each do |listener, func|
                listener.send func, Marshal.load(payload)
              end
            end
          end
        end
      end
    end
  end
end
