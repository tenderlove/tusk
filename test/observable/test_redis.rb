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

Dir.chdir(File.join(File.dirname(__FILE__), '..')) do
  `redis-server redis-test.conf`
end

at_exit {
  next if $!

  exit_code = MiniTest::Unit.new.run(ARGV)

  processes = `ps -A -o pid,command | grep [r]edis-test`.split("\n")
  pids = processes.map { |process| process.split(" ")[0] }
  puts "Killing test redis server..."
  pids.each { |pid| Process.kill("KILL", pid.to_i) }

  exit exit_code
}
