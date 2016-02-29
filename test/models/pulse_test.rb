require 'test_helper'

class PulseTest < ActiveSupport::TestCase
	self.use_transactional_fixtures = true

#	test "node one" do
#		assert_equal(1000, Pulse.where(node: Node.find_by_title(:one)).count())
#		assert_equal(1001, Pulse.where(node: Node.find_by_title(:two)).count())
#	end

	# TODO timezone testing

end
