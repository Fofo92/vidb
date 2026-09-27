require "test_helper"
require "minitest/mock"

module Tv
  class KaffeineScheduleLockTest < ActiveSupport::TestCase
    test "returns the operation result while holding the database lock" do
      assert_equal :completed, KaffeineScheduleLock.new.synchronize { :completed }
    end

    test "refuses to run when the lock is unavailable" do
      ActiveRecord::Base.connection.stub(:select_value, false) do
        assert_raises(KaffeineScheduleLock::Busy) do
          KaffeineScheduleLock.new.synchronize { flunk "operation entered without the lock" }
        end
      end
    end
  end
end
