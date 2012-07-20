require 'tusk/observers/pg'
require 'helper'

module Tusk
  module Observers
    class TestPg < MiniTest::Unit::TestCase
      class InstanceObserver
        include Tusk::Observers::PG

        def tick
          changed
          notify_observers
        end

        def connection
          Thread.current[:conn] ||= ::PG::Connection.new :dbname => 'postgres'
        end
      end

      def test_changed?
        o = InstanceObserver.new
        refute o.changed?
        o.changed
        assert o.changed?
      end

      def test_changed
        o = InstanceObserver.new
        refute o.changed?
        o.changed false
        refute o.changed?
        o.changed
        assert o.changed
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_count_observers
        o = InstanceObserver.new

        assert_raises(NotImplementedError) do
          o.count_observers
        end
      end

      # Doesn't make sense in a multi-proc environment, so raise an error
      def test_delete_observers
        o = InstanceObserver.new

        assert_raises(NotImplementedError) do
          o.delete_observers
        end
      end

      def test_observer_fires
        o = InstanceObserver.new
        q = Queue.new

        o.add_observer(Class.new {
          define_method(:update) { q.push :foo }
        }.new)

        o.changed
        o.notify_observers

        assert_equal :foo, q.pop
      end

      def test_observer_only_fires_on_change
        o = InstanceObserver.new
        q = Queue.new

        o.add_observer(Class.new {
          define_method(:update) { q.push :foo }
        }.new)

        o.notify_observers
        assert q.empty?
      end
    end
  end
end
