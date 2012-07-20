require 'pg'
require 'tusk/observers/pg'
require 'helper'

module Tusk
  module Observers
    class TestPg < TestCase
      include ObserverTests

      class Timer
        include Tusk::Observers::PG

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
        Tusk::Observers::PG
      end
    end
  end
end
