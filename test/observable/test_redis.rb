require 'redis'
require 'tusk/observable/redis'
require 'helper'

module Tusk
  module Observable
    class TestRedis < TestCase
      include ObserverTests

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
        Tusk::Observable::Redis
      end
    end

    class TestClassRedis < TestCase
      include ObserverTests

      def build_observable
        Class.new {
          extend Tusk::Observable::Redis

          def self.tick
            changed
            notify_observers
          end

          def self.connection
            Thread.current[:redis] ||= ::Redis.new
          end
        }
      end

      def observer_module
        Tusk::Observable::Redis
      end
    end
  end
end
