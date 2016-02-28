require 'test_helper'

class PulseTest < ActiveSupport::TestCase
	self.use_transactional_fixtures = true

#	test "node one" do
#		assert_equal(1000, Pulse.where(node: Node.find_by_title(:one)).count())
#		assert_equal(1001, Pulse.where(node: Node.find_by_title(:two)).count())
#	end

	test "daily_slot_per_month" do
		tz = Time.zone.now.formatted_offset		
		q_f1 = "(extract(hour from timezone('#{tz}', pulse_time)) >= 8 and extract(hour from timezone('#{tz}', pulse_time)) < 19 and extract(dow from timezone('#{tz}', pulse_time)) between 1 and 5 and (extract(month from timezone('#{tz}', pulse_time)), extract(day from timezone('#{tz}', pulse_time))) not in ((1,1),(1,6),(4,25),(5,1),(6,2),(8,15),(11,1),(12,8),(12,25),(12,26)))"
		# q_f1 = "(extract(hour from timezone('#{tz}', pulse_time)) >= 8 and extract(hour from timezone('#{tz}', pulse_time)) < 19)"
		q_f2 = "not (#{q_f1})"
		# assert_equal([[5, 0.66]], Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f1, '2015-05-04', '2015-05-09'))
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f1, '2015-05-04', '2015-05-09')
		assert_equal([1, 2015, 5], [q.length, q[0].year, q[0].month])
		assert_in_delta(0.66, q[0].power)
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f2, '2015-05-04', '2015-05-09')
		assert_equal([2015, 5, 0.78], [q[0].year, q[0].month, q[0].power])

		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f1, '2015-05-03', '2015-05-09')
		assert_in_delta(0.55, q[0].power)
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f2, '2015-05-03', '2015-05-09')
		assert_equal([2015, 5, 0.89], [q[0].year, q[0].month, q[0].power])

		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed20), q_f1, '2014-12-10', '2015-01-10')
		assert_equal([[2014, 12, 0.14], [2015, 1, 0.12222222222222223]], [[q[0].year, q[0].month, q[0].power], [q[1].year, q[1].month, q[1].power]])
		# assert_in_delta(0.14, q[0].power)
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed20), q_f2, '2014-12-10', '2015-01-10')
		assert_equal([[2014, 12, 0.34], [2015, 1, 0.3577777777777778]], [[q[0].year, q[0].month, q[0].power], [q[1].year, q[1].month, q[1].power]])
		# assert_equal([2015, 5, 0.78], [q[0].year, q[0].month, q[0].power])
		# q = Pulse.daily_per_month(Node.find_by_title(:fixed60), '2015-05-03', '2015-05-09')
		# assert_equal([[5, 1.44]], [q[0].year, q[0].month, q[0].power])
	end

	# TODO timezone testing

end
