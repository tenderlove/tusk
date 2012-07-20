require 'minitest/autorun'

module Tusk
  class TestCase < MiniTest::Unit::TestCase
    module ObserverTests
      class QueueingObserver
        def initialize q
          @q = q
        end

        def update
          @q.push :foo
        end
      end

      def test_changed?
        o = build_observable
        refute o.changed?
        o.changed
        assert o.changed?
      end

      def test_changed
        o = build_observable
        refute o.changed?
        o.changed false
        refute o.changed?
        o.changed
        assert o.changed
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_count_observers
        o = build_observable

        assert_raises(NotImplementedError) do
          o.count_observers
        end
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_delete_observers
        o = build_observable

        assert_raises(NotImplementedError) do
          o.delete_observers
        end
      end

      def test_observer_fires
        o = build_observable
        q = Queue.new

        o.add_observer QueueingObserver.new q

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop
      end

      def test_observer_only_fires_on_change
        o = build_observable
        q = Queue.new

        o.add_observer QueueingObserver.new q

        o.notify_observers
        assert q.empty?
      end

      def test_delete_observer
        o        = build_observable
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
        o        = build_observable
        q        = Queue.new
        observer = QueueingObserver.new q

        o.delete_observer observer
        o.changed
        o.notify_observers

        assert q.empty?
      end

      def test_no_connection
        mod = observer_module
        obj = Class.new { include mod }.new

        assert_raises(NotImplementedError) do
          obj.changed
          obj.notify_observers
        end
      end

      private

      def build_observable
        raise NotImplementedError
      end

      def observer_module
        raise NotImplementedError
      end
    end
  end
end
