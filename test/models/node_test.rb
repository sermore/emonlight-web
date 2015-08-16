require 'test_helper'

class NodeTest < ActiveSupport::TestCase
	test "check nodes" do
		assert_equal(4, Node.count)
	end
end
