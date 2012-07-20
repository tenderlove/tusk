require 'pg'
require 'tusk/observable/pg'
require 'helper'

module Tusk
  module Observable
    class TestPg < TestCase
      include ObserverTests

      class Timer
        include Tusk::Observable::PG

        def tick
          changed
          notify_observers
        end

        def connection
          Thread.current[:conn] ||= ::PG::Connection.new :dbname => 'postgres'
        end
      end

      private

      def build_observable
        Timer.new
      end

      def observer_module
        Tusk::Observable::PG
      end
    end

    class TestClassPg < TestCase
      include ObserverTests

      def build_observable
        Class.new {
          extend Tusk::Observable::PG

          def self.tick
            changed
            notify_observers
          end

          def self.connection
            Thread.current[:conn] ||= ::PG::Connection.new :dbname => 'postgres'
          end
        }
      end

      def observer_module
        Tusk::Observable::PG
      end
    end
  end
end
