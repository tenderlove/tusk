require 'pg'
require 'tusk/observables/pg'
require 'helper'

module Tusk
  module Observables
    class TestPg < TestCase
      include ObserverTests

      class Timer
        include Tusk::Observables::PG

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
        Tusk::Observables::PG
      end
    end

    class TestClassPg < TestCase
      include ObserverTests

      def build_observable
        Class.new {
          extend Tusk::Observables::PG

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
        Tusk::Observables::PG
      end
    end
  end
end
