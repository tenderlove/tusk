require 'tusk/observers/pg'
require 'helper'

module Tusk
  module Observers
    class TestPg < MiniTest::Unit::TestCase
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

      class QueueingObserver
        def initialize q
          @q = q
        end

        def update
          @q.push :foo
        end
      end

      def test_changed?
        o = Timer.new
        refute o.changed?
        o.changed
        assert o.changed?
      end

      def test_changed
        o = Timer.new
        refute o.changed?
        o.changed false
        refute o.changed?
        o.changed
        assert o.changed
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_count_observers
        o = Timer.new

        assert_raises(NotImplementedError) do
          o.count_observers
        end
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_delete_observers
        o = Timer.new

        assert_raises(NotImplementedError) do
          o.delete_observers
        end
      end

      def test_observer_fires
        o = Timer.new
        q = Queue.new

        o.add_observer QueueingObserver.new q

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop
      end

      def test_observer_only_fires_on_change
        o = Timer.new
        q = Queue.new

        o.add_observer QueueingObserver.new q

        o.notify_observers
        assert q.empty?
      end

      def test_delete_observer
        o        = Timer.new
        q        = Queue.new
        observer = QueueingObserver.new q

        o.add_observer observer

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop

        o.delete_observer observer

        o.changed
        o.notify_observers

        assert q.empty?
      end

      def test_delete_never_added
        o        = Timer.new
        q        = Queue.new
        observer = QueueingObserver.new q

        o.delete_observer observer
        o.changed
        o.notify_observers

        assert q.empty?
      end

      def test_no_connection
        obj = Class.new {
          include Tusk::Observers::PG
        }.new

        assert_raises(NotImplementedError) do
          obj.changed
          obj.notify_observers
        end
      end
    end
  end
end
