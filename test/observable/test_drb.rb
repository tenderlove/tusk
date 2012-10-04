require 'helper'
require 'tusk/observable/drb'

module Tusk
  module Observable
    class TestDRb < TestCase
      include ObserverTests

      class Timer
        include Tusk::Observable::DRb

        def tick
          changed
          notify_observers
        end
      end

      def setup
        super
        DRb::Server.start
      end

      def teardown
        super
        DRb::Server.stop
      end

      def test_no_connection
        skip "not implementing for now"
      end

      private

      def build_observable
        Timer.new
      end

      def observer_module
        Tusk::Observable::DRb
      end
    end

    class TestClassDRb < TestCase
      include ObserverTests

      def setup
        super
        DRb::Server.start
      end

      def teardown
        super
        DRb::Server.stop
      end

      def build_observable
        Class.new {
          extend Tusk::Observable::DRb

          def self.tick
            changed
            notify_observers
          end
        }
      end

      def test_no_connection
        skip "not implementing for now"
      end

      def observer_module
        Tusk::Observable::DRb
      end
    end
  end
end
