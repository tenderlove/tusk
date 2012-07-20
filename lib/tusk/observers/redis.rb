module Tusk
  module Observers
    module Redis
      attr_reader :subscribers

      def initialize *args
        super

        @sub_lock       = Mutex.new
        @observer_state = false
        @subscribers    = {}
        @_listener      = nil
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
        connection.publish channel, nil
        @observer_state = false
      end

      def add_observer object, func = :update
        observer_set = Latch.new
        observing    = Latch.new

        observing.release if subscribers.key? channel

        subscribers.fetch(channel) { |k|
          Thread.new {
            observer_set.await
            start_listener(observing)
          }
          subscribers[k] = {}
        }[object] = func

        observer_set.release
        observing.await
      end

      def delete_observer o
        subscribers.fetch(channel, {}).delete o
      end

      private

      def connection
        raise NotImplementedError, "you must implement the `connection` method for the redis obsever"
      end

      def channel
        "a" + Digest::MD5.hexdigest("#{self.class.name}#{object_id}")
      end

      def start_listener latch
        connection.subscribe(channel) do |on|
          on.subscribe { |c| latch.release }

          on.message do |c, message|
            subscribers.fetch(c, {}).each do |object,m|
              object.send m
            end
          end
        end
      end
    end
  end
end
