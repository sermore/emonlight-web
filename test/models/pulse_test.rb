require 'test_helper'

class PulseTest < ActiveSupport::TestCase
	self.use_transactional_fixtures = true

#	test "node one" do
#		assert_equal(1000, Pulse.where(node: Node.find_by_title(:one)).count())
#		assert_equal(1001, Pulse.where(node: Node.find_by_title(:two)).count())
#	end

	test "hourly mean" do
		assert_in_delta(60.0, Pulse.hourly_mean(Node.find_by_title(:fixed60)))
		assert_equal(60.0, Pulse.hourly_mean(Node.find_by_title(:fixed60), '2015-05-01 00:00', '2015-05-01 1:30'))
		assert_equal(60.0, Pulse.hourly_mean(Node.find_by_title(:fixed60), '2015-05-01 00:00', '2015-05-01 12:00'))
		assert_in_delta(41.18411375337093, Pulse.hourly_mean(Node.find_by_title(:wday)))
		assert_equal(40.0, Pulse.hourly_mean(Node.find_by_title(:wday), '2015-05-01', '2015-05-15'))
		assert_equal(1030.0, Pulse.hourly_mean(Node.find_by_title(:hourly), '2015-05-01 03:00', '2015-05-01 04:00'))
		assert_equal(1115.0, Pulse.hourly_mean(Node.find_by_title(:hourly), '2015-05-01 00:00', '2015-05-02 00:00'))
	end

	test "daily mean" do
		assert_equal(1440.0, Pulse.daily_mean(Node.find_by_title(:fixed60)))
		assert_equal(1440.0, Pulse.daily_mean(Node.find_by_title(:fixed60), '2015-05-01', '2015-05-02'))
		assert_equal(1440.0, Pulse.daily_mean(Node.find_by_title(:fixed60), '2015-05-01 13:00', '2015-05-02 21:00'))
		assert_equal(720.0, Pulse.daily_mean(Node.find_by_title(:fixed60), '2015-05-01 00:00', '2015-05-01 12:00'))
		assert_in_delta(988.4187300809022, Pulse.daily_mean(Node.find_by_title(:wday)))
		assert_equal(960.0, Pulse.daily_mean(Node.find_by_title(:wday), '2015-05-01', '2015-05-15'))
	end

	test "monthly mean" do
		assert_in_delta(14400.0, Pulse.monthly_mean(Node.find_by_title(:fixed20)))
		# assert_equal(47520.0, Pulse.monthly_mean(Node.find_by_title(:monthly)))
		assert_equal(14400.0, Pulse.monthly_mean(Node.find_by_title(:fixed20), '2014-12-07', '2015-02-04'))
		assert_equal(46740.95296932954, Pulse.monthly_mean(Node.find_by_title(:monthly), '2015-05-01', '2015-07-01'))
	end

	test "yearly mean" do
		assert_equal(12959.0, Pulse.yearly_mean(Node.find_by_title(:fixed60)))
		assert_equal(95039.0, Pulse.yearly_mean(Node.find_by_title(:monthly)))
		assert_equal(44640.0, Pulse.yearly_mean(Node.find_by_title(:monthly), '2015-05-01', '2015-06-01'))
	end

	test "weekly" do
		assert_equal([[0, 1.44], [1, 1.44], [2, 1.44], [3, 1.44], [4, 1.44], [5, 1.44], [6, 1.44]], Pulse.weekly(Node.find_by_title(:fixed60)))
		assert_equal([[0, 1.44], [5, 1.44], [6, 1.44]], Pulse.weekly(Node.find_by_title(:fixed60), '2015-05-01', '2015-05-04'))
		assert_equal([[0, 0.24], [1, 0.48], [2, 0.72], [3, 0.96], [4, 1.2], [5, 1.44], [6, 1.68]], Pulse.weekly(Node.find_by_title(:wday)))
		assert_equal([[0, 0.24], [1, 0.48], [2, 0.72], [3, 0.96], [4, 1.2], [5, 1.44], [6, 1.68]], Pulse.weekly(Node.find_by_title(:wday), '2015-05-01', '2015-05-08'))
	end

	test "daily" do
		assert_equal([[0, 60.0], [1, 60.0], [2, 60.0], [3, 60.0], [4, 60.0], [5, 60.0], [6, 60.0], [7, 60.0], [8, 60.0], [9, 60.0], [10, 60.0], [11, 60.0], [12, 60.0], [13, 60.0], [14, 60.0], [15, 60.0], [16, 60.0], [17, 60.0], [18, 60.0], [19, 60.0], [20, 60.0], [21, 60.0], [22, 60.0], [23, 60.0]], Pulse.daily(Node.find_by_title(:fixed60), '2015-05-01', '2015-05-11'))
		assert_equal([[7, 60.0], [8, 60.0], [9, 60.0], [10, 60.0], [11, 60.0], [12, 60.0], [13, 60.0], [14, 60.0]], Pulse.daily(Node.find_by_title(:fixed60), '2015-05-01 07:00', '2015-05-01 15:00'))
		assert_equal([[0.0, 41.0], [1.0, 41.0], [2.0, 41.0], [3.0, 41.0], [4.0, 41.0], [5.0, 41.0], [6.0, 41.0], [7.0, 41.0], [8.0, 41.0], [9.0, 41.0], [10.0, 41.0], [11.0, 41.0], [12.0, 41.0], [13.0, 41.0], [14.0, 41.0], [15.0, 41.0], [16.0, 41.0], [17.0, 41.0], [18.0, 41.0], [19.0, 41.0], [20.0, 41.0], [21.0, 41.0], [22.0, 41.0], [23.0, 41.0]], Pulse.daily(Node.find_by_title(:wday), '2015-05-01', '2015-05-19'))
		assert_equal([[0, 1000.0], [1, 1010.0], [2, 1020.0], [3, 1030.0], [4, 1040.0], [5, 1050.0], [6, 1060.0], [7, 1070.0], [8, 1080.0], [9, 1090.0], [10, 1100.0], [11, 1110.0], [12, 1120.0], [13, 1130.0], [14, 1140.0], [15, 1150.0], [16, 1160.0], [17, 1170.0], [18, 1180.0], [19, 1190.0], [20, 1200.0], [21, 1210.0], [22, 1220.0], [23, 1230.0]], Pulse.daily(Node.find_by_title(:hourly), '2015-05-01', '2015-05-02'))
		assert_equal([[0, 1000.0], [1, 1010.0], [2, 1020.0], [3, 1030.0], [4, 1040.0], [5, 1050.0], [6, 1060.0], [7, 1070.0], [8, 1080.0], [9, 1090.0], [10, 1100.0], [11, 1110.0], [12, 1120.0], [13, 1130.0], [14, 1140.0], [15, 1150.0], [16, 1160.0], [17, 1170.0], [18, 1180.0], [19, 1190.0], [20, 1200.0], [21, 1210.0], [22, 1220.0], [23, 1230.0]], Pulse.daily(Node.find_by_title(:hourly), '2015-05-01', '2015-05-08'))
	end

	test "monthly" do
		assert_equal([[1, 1.44], [2, 1.44], [3, 1.44], [4, 1.44], [5, 1.44], [6, 1.44], [7, 1.44], [8, 1.44], [9, 1.44]], Pulse.monthly(Node.find_by_title(:fixed60)))
		assert_equal([[1, 1.44], [2, 1.44], [3, 1.44], [4, 1.44], [5, 1.44], [6, 1.44], [7, 1.44], [8, 1.44], [9, 1.44], [10, 1.44], [11, 1.44], [12, 1.44], [13, 1.44], [14, 1.44], [15, 1.44], [16, 1.44], [17, 1.44], [18, 1.44], [19, 1.44], [20, 1.44], [21, 1.44], [22, 1.44], [23, 1.44], [24, 1.44], [25, 1.44], [26, 1.44], [27, 1.44], [28, 1.44], [29, 1.44], [30, 1.44], [31, 1.44]], Pulse.monthly(Node.find_by_title(:monthly), '2015-05-01', '2015-06-01'))
		assert_equal([[1, 1.56], [2, 1.56], [3, 1.56], [4, 1.56], [5, 1.56], [6, 1.56], [7, 1.56], [8, 1.56], [9, 1.56], [10, 1.56], [11, 1.56], [12, 1.56], [13, 1.56], [14, 1.56], [15, 1.56], [16, 1.56], [17, 1.56], [18, 1.56], [19, 1.56], [20, 1.56], [21, 1.56], [22, 1.56], [23, 1.56], [24, 1.56], [25, 1.56], [26, 1.56], [27, 1.56], [28, 1.56], [29, 1.56], [30, 1.56], [31, 1.44]], Pulse.monthly(Node.find_by_title(:monthly)))
	end

	test "yearly" do
		assert_equal([[5, 12.96]], Pulse.yearly(Node.find_by_title(:fixed60)))
		assert_equal([[5, 44.64]], Pulse.yearly(Node.find_by_title(:monthly), '2015-05-01', '2015-06-01'))
		assert_equal([[5, 44.64], [6, 50.4]], Pulse.yearly(Node.find_by_title(:monthly)))
	end

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
		assert_equal([[5, 1.44]], Pulse.daily_per_month(Node.find_by_title(:fixed60), '2015-05-03', '2015-05-09'))

		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f1, '2015-05-03', '2015-05-09')
		assert_in_delta(0.55, q[0].power)
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed60), q_f2, '2015-05-03', '2015-05-09')
		assert_equal([2015, 5, 0.89], [q[0].year, q[0].month, q[0].power])

		assert_equal([[1, 0.48], [12, 0.48]], Pulse.daily_per_month(Node.find_by_title(:fixed20), '2014-12-10', '2015-01-10'))
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed20), q_f1, '2014-12-10', '2015-01-10')
		assert_equal([[2014, 12, 0.14], [2015, 1, 0.12222222222222223]], [[q[0].year, q[0].month, q[0].power], [q[1].year, q[1].month, q[1].power]])
		# assert_in_delta(0.14, q[0].power)
		q = Pulse.daily_slot_per_month(Node.find_by_title(:fixed20), q_f2, '2014-12-10', '2015-01-10')
		assert_equal([[2014, 12, 0.34], [2015, 1, 0.3577777777777778]], [[q[0].year, q[0].month, q[0].power], [q[1].year, q[1].month, q[1].power]])
		# assert_equal([2015, 5, 0.78], [q[0].year, q[0].month, q[0].power])
		# q = Pulse.daily_per_month(Node.find_by_title(:fixed60), '2015-05-03', '2015-05-09')
		# assert_equal([[5, 1.44]], [q[0].year, q[0].month, q[0].power])
	end

end
