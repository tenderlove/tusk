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

      class PayloadQueueingObserver < QueueingObserver
        def update(*args)
          @q.push(args)
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

      def test_delete_observers
        o = build_observable

        q = Queue.new

        o.add_observer QueueingObserver.new q
        o.delete_observers
        o.changed
        o.notify_observers
        assert q.empty?
      end

      def test_count_observers
        o = build_observable
        assert_equal 0, o.count_observers

        q = Queue.new

        o.add_observer QueueingObserver.new q
        assert_equal 1, o.count_observers

        o.add_observer QueueingObserver.new q
        assert_equal 2, o.count_observers

        o.delete_observers
        assert_equal 0, o.count_observers
      end

      def test_observer_fires
        o = build_observable
        q = Queue.new

        o.add_observer QueueingObserver.new q

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop
      end

      def test_notification_payload
        o = build_observable
        q = Queue.new

        o.add_observer PayloadQueueingObserver.new q

        o.changed
        o.notify_observers :payload

        assert_equal [:payload], q.pop
      end

      def test_multiple_observers
        o = build_observable
        q = Queue.new

        o.add_observer QueueingObserver.new q
        o.add_observer QueueingObserver.new q

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop
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

        assert_raises(NameError) do
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
