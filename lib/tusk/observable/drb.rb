require 'drb'
require 'digest/md5'

module Tusk
  module Observable
    ###
    # An observer implementation for DRb.  This module requires that
    # you start a DRb server, which can be done via Server.start
    #
    # This observer works across processes.
    #
    # Example:
    #
    #     require 'tusk/observable/drb'
    #
    #     class Timer
    #       include Tusk::Observable::DRb
    #
    #       # Start the DRb server. Do this once
    #       Thread.new { Server.start }
    #
    #       def tick
    #         changed
    #         notify_observers
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
    module DRb
      class Server
        URI = 'druby://localhost:8787'

        def self.start
          ::DRb.start_service URI, new
        end

        def self.stop
          ::DRb.stop_service
        end

        def initialize
          @channels = Hash.new { |h,k| h[k] = {} }
        end

        def watch channel, proxy
          @channels[channel][proxy] = proxy
        end

        def signal channel, args
          @channels[channel].each { |proxy,|
            proxy.notify args
          }
        end

        def delete_observer channel, o
          @channels[channel].delete o
        end

        def delete channel
          @channels.delete channel
        end
      end

      class Proxy # :nodoc:
        include ::DRb::DRbUndumped

        def initialize d, func
          @delegate = d
          @func     = func
        end

        def notify args
          @delegate.send(@func, *args)
        end
      end

      def self.extended klass
        super

        klass.instance_eval do
          @bus = DRbObject.new_with_uri uri
          @observer_state = false
          @subscribers      = {}
        end
      end

      def initialize *args
        super

        @bus = DRbObject.new_with_uri uri
        @observer_state = false
        @subscribers      = {}
      end

      # Add +observer+ as an observer to this object.  The +object+ will
      # receive a notification when #changed? returns true and #notify_observers
      # is called.
      #
      # +func+ method is called on +object+ when notifications are sent.
      def add_observer object, func = :update
        unless ::DRb.thread && ::DRb.thread.alive?
          ::DRb.start_service
        end

        proxy = Proxy.new object, func
        @subscribers[object] = proxy
        @bus.watch channel, proxy
      end

      # If this object's #changed? state is true, this method will notify
      # observing objects.
      def notify_observers(*args)
        return unless changed?
        @bus.signal channel, args
        changed false
      end

      # Remove all observers associated with this object *in the current
      # process*. This method will not impact observers of this object in
      # other processes.
      def delete_observers
        @bus.delete channel
        @subscribers.clear
      end

      # Remove +observer+ so that it will no longer receive notifications.
      def delete_observer o
        proxy = @subscribers.delete o
        @bus.delete_observer channel, proxy
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

      # Returns the number of observers associated with this object *in the
      # current process*.  If the object is observed across multiple processes,
      # the returned count will not reflect the other processes.
      def count_observers
        @subscribers.length
      end

      private

      def uri
        Server::URI
      end

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end
    end
  end
end
