require 'redis'
require 'tusk/observers/redis'
require 'helper'

module Tusk
  module Observers
    class TestRedis < TestCase
      include ObserverTests

      class Timer
        include Tusk::Observers::Redis

        def tick
          changed
          notify_observers
        end

        def connection
          Thread.current[:redis] ||= ::Redis.new
        end
      end

      class QueueingObserver
        def initialize q
          @q = q
        end

        def update
          @q.push :foo
        end
      end

      private

      def build_observable
        Timer.new
      end

      def observer_module
        Tusk::Observers::Redis
      end
    end
  end
end
