require 'test_helper'

class PulseTestImport < ActiveSupport::TestCase

	test "calc_power" do
		assert_equal(3600.0, Pulse.calc_power(1000, 1.0))
		assert_equal(1800.0, Pulse.calc_power(1000, 2.0))
	end

	test "time conversion" do
		t1 = Time.parse('2015-04-08 14:45:34.234403')
		assert_equal(234403000, t1.nsec)
		t2 = Time.at(t1.to_i, t1.nsec/1.0e3)
		assert_equal(t1.nsec, t2.nsec)
		assert_equal(t1.to_i, t2.to_i)
		assert_equal(t1, t2)
		p1 = Pulse.create(pulse_time: t1)
		p2 = Pulse.find_by_pulse_time(t2)
		assert_equal(p1.pulse_time, p2.pulse_time)
	end	

	test "calc_last_time" do
		current_node = Node.find_by_title('fixed60')
		assert_equal(nil, Pulse.calc_last_time(current_node, Time.parse('2014-01-01')))
		assert_equal(Time.parse('2015-05-09 23:59:00 UTC'), Pulse.calc_last_time(current_node, Time.parse('2015-07-01')))
	end

	test "read row sec msec" do
		t = Time.parse('2014-07-08 14:45:34.234403')
		row = [t.to_i, t.tv_nsec]
		t1 = Pulse.read_row_sec_msec(row)
		assert_equal([t.to_i, t.tv_nsec], [t1[0].to_i, t1[0].tv_nsec])
	end	

	test "read power" do
		current_node = Node.find_by_title('fixed60')
		last_time = nil
		time = Time.parse('2014-07-08 14:45:34.234403')
		q = Pulse.read_power(current_node, time, last_time)
		#puts time, time.to_f, time.tv_nsec, row, q
		assert_equal([ nil, time, 0.0 ], q)
		last_time = time.clone
		time += 1.5
		assert_equal(1.5, time - last_time)
		q = Pulse.read_power(current_node, time, last_time)
		assert_equal([last_time, time, Pulse.calc_power(current_node.pulses_per_kwh, 1.5)], q)
	end

	test "read simple" do
		node = Node.find_by_title('fixed60')
		time = Time.parse('2014-07-08 14:45:34.234403')
		rows = [ time, time += 1.5, time += 4, time += 10 ]
		c = Pulse.read node, rows, false, :read_simple, :read_row_simple
		assert_equal(4, c)
	end

	test "read" do
		current_node = Node.find_by_title('fixed60')
		t = Time.parse('2014-07-08 14:45:34')
		ts = []
		for i in 1..5 do
			ts << [t.to_i, t.tv_nsec]
			t += 10
		end
		assert_equal(5, ts.length)
		q = Pulse.where("pulse_time between :t1 and :t2", { t1: '2014-07-08 14:45:34', t2: '2014-07-08 14:46:34'})
		assert(0, q.length)
		assert_equal(5, Pulse.read(current_node, ts, false, :read_simple, :read_row_sec_msec))
		q = Pulse.where("pulse_time between :t1 and :t2", { t1: '2014-07-08 14:45:34', t2: '2014-07-08 14:46:34'})
		assert(5, q.length)
		assert_equal(0, Pulse.read(current_node, ts, false, :read_simple, :read_row_sec_msec, [Pulse.read_row_sec_msec(ts[0])[0], Pulse.read_row_sec_msec(ts[-1])[0]]))
		assert_equal(0, Pulse.read(current_node, ts[1, 3], false, :read_simple, :read_row_sec_msec, [Pulse.read_row_sec_msec(ts[0])[0], Pulse.read_row_sec_msec(ts[-1])[0]]))
	end

end