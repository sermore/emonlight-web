require 'test_helper'

class NodeTest < ActiveSupport::TestCase
	
	test "check nodes" do
		assert_equal(6, Node.count)
		assert_equal(1000, Node.find_by_title('fixed60').pulses_per_kwh)
	end
end
