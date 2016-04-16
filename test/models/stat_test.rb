require 'test_helper'

class StatTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = true

  Time.zone = 'Europe/Rome'

  test "tz" do
    n = Node.find_by_title('wday')
    assert_equal('Europe/Rome', Stat.tzn(n))
    n.time_zone = 'Rome'
    assert_equal('Europe/Rome', Stat.tzn(n))
    s = Stat.new(stat: Stat::GROUP_BY_WDAY, node: n)
    s.node.time_zone = 'Central America'
    assert_equal("extract(dow from timezone('America/Guatemala', timezone('UTC', pulse_time)))::integer", s.GROUPING())
    s.node.time_zone = "UTC"
    assert_equal("extract(dow from timezone('Etc/UTC', timezone('UTC', pulse_time)))::integer", s.GROUPING())
    s.node.time_zone = "Rome"
    assert_equal("Europe/Rome", s.tz)
    assert_equal("extract(dow from timezone('Europe/Rome', timezone('UTC', pulse_time)))::integer", s.GROUPING())
  end

  test "constants" do
    s = Stat.new(stat: Stat::GROUP_BY_HOUR, where_clause: :F1, node: Node.find_by_title(:fixed60))
    assert_equal(3600.0, s.STAT_TIME)
    assert_equal("extract(hour from timezone('#{s.tz}', timezone('UTC', pulse_time)))::integer", s.GROUPING)
    t = Time.zone.parse('2015-03-12 16:34:23')
    assert_equal(t.hour, s.TIME_GROUPING(t))
    assert_equal((23+34*60)/3600.0, s.DIFF_TIME(t))
    assert_equal("count(pulse_time) as sum_val, extract(hour from timezone('Europe/Rome', timezone('UTC', pulse_time)))::integer as group_by, count(distinct(trunc(extract(epoch from timezone('Europe/Rome', timezone('UTC', pulse_time)))/86400.0)))::float as sum_weight", s.SELECT)
    assert_equal("F1", s.where_clause)
    assert_equal("(extract(hour from timezone('Europe/Rome', timezone('UTC', pulse_time))) >= 8 and extract(hour from timezone('Europe/Rome', timezone('UTC', pulse_time))) < 19 and extract(dow from timezone('Europe/Rome', timezone('UTC', pulse_time))) between 1 and 5 and (extract(month from timezone('Europe/Rome', timezone('UTC', pulse_time))), extract(day from timezone('Europe/Rome', timezone('UTC', pulse_time)))) not in ((1,1),(1,6),(4,25),(5,1),(6,2),(8,15),(11,1),(12,8),(12,25),(12,26)))", s.WHERE_CLAUSE())
  end

  test "verify period" do
    Time.zone = 'Europe/Rome'
    s = Stat.new(node: Node.find_by_title(:fixed60), stat: Stat::GROUP_BY_HOUR, period: Stat.from_period(23, Stat::P_HOUR))
    assert_equal([nil, nil], s.verify_period('2015-04-01'))
    assert_equal([Time.zone.parse('2015-05-01 01:00:00'), Time.zone.parse('2015-05-02')], s.verify_period('2015-05-02 00:00'))
    assert_equal([Time.zone.parse('2015-05-01 03:00:00'), Time.zone.parse('2015-05-02 02:00')], s.verify_period('2015-05-02 02:00'))
    assert_equal([Time.zone.parse('2015-05-01 16:00:00'), Time.zone.parse('2015-05-02 15:35:00')], s.verify_period('2015-05-02 15:35:32'))
    assert_equal([Time.zone.parse('2015-05-09 20:00'), Time.zone.parse('2015-05-09 23:59:00')], s.verify_period('2015-05-10 19:23'))
  end

  test "calc raw mean" do
    Time.zone = 'Europe/Rome'
    n = Node.find_by_title(:fixed60)
    s = Stat.create(node: n, stat: Stat::DAILY)
    assert_equal([1440.0, 1], s.calc_raw_mean(s.convert_date('2015-05-01'), s.convert_date('2015-05-02')))
    s = Stat.new(node: Node.find_by_title(:wday), stat: Stat::DAILY)
    assert_equal([1440.0, 1], s.calc_raw_mean(s.convert_date('2015-05-01'), s.convert_date('2015-05-02')))
    assert_equal([1560.0, 2], s.calc_raw_mean(s.convert_date('2015-05-01'), s.convert_date('2015-05-03')))
    assert_equal([1120.0, 3], s.calc_raw_mean(s.convert_date('2015-05-01'), s.convert_date('2015-05-04')))
    assert_equal([960.0, 4], s.calc_raw_mean(s.convert_date('2015-05-01'), s.convert_date('2015-05-05')))
    s1 = Stat.new(node: Node.find_by_title(:fixed60), stat: Stat::DAILY, where_clause: :F1)
    assert_equal([0.0, 1], s1.calc_raw_mean(s1.convert_date('2015-05-01'), s1.convert_date('2015-05-02')))
    assert_equal([164.75, 4.0], s1.calc_raw_mean(s1.convert_date('2015-05-01'), s1.convert_date('2015-05-05')))
    s2 = Stat.new(node: Node.find_by_title(:fixed60), stat: Stat::DAILY, where_clause: :F2)
    assert_equal([1275.0, 4.0], s2.calc_raw_mean(s2.convert_date('2015-05-01'), s2.convert_date('2015-05-05')))
    assert_equal([341.53846153846155, 6.5], s1.calc_raw_mean(s1.convert_date('2015-05-01'), s1.convert_date('2015-05-07 12:00')))
    assert_equal([1098.3076923076924, 6.5], s2.calc_raw_mean(s2.convert_date('2015-05-01'), s2.convert_date('2015-05-07 12:00')))
  end

  test "calc mean" do
    Time.zone = 'Europe/Rome'
    # assert_equal(0, Stat.count)
    fixed60 = Node.find_by_title(:fixed60)
    s = Stat.create(node: fixed60, stat: Stat::DAILY)
    assert_equal(0.0, s.calc_mean('2015-04-01'))
    assert_equal(1440.0, s.calc_mean('2015-05-02'))
    assert_equal(1440.0, s.calc_mean('2015-05-03'))
    assert_equal(1440.0, s.calc_mean('2015-05-04 12:00'))
    assert_equal(1440.0, s.calc_mean('2015-05-05'))
    assert_throws(:mean_fails) { s.calc_mean('2015-05-03 08:00') }
    # test for simple period 1/5 => 60, 2/5 => 70, 3/5 => 10, ...
    s = Stat.new(node: Node.find_by_title(:wday), stat: Stat::DAILY)
    assert_equal(1440.0, s.calc_mean('2015-05-02'))
    assert_equal(1560.0, s.calc_mean('2015-05-03'))
    # with where clause
    s1 = Stat.new(node: fixed60, stat: Stat::DAILY, where_clause: :F1)
    assert_equal(0.0, s1.calc_mean('2015-05-03'))
    assert_equal(164.75, s1.calc_mean('2015-05-05'))
    s2 = Stat.new(node: fixed60, stat: Stat::DAILY, where_clause: :F2)
    assert_equal(1275.0, s2.calc_mean('2015-05-05'))
    assert_equal(263.6, s1.calc_mean('2015-05-06'))
    assert_equal(1176.0, s2.calc_mean('2015-05-06'))
    assert_equal(341.2307692307692, s1.calc_mean('2015-05-07 12:00'))
    assert_equal(1098.3076923076924, s2.calc_mean('2015-05-07 12:00'))
  end

  test "calc mean_on_period" do
    Time.zone = 'Europe/Rome'
    fixed60 = Node.find_by_title(:fixed60)
    # test for period not available
    s = Stat.create(node: fixed60, stat: Stat::DAILY, period: Stat.from_period(1, Stat::P_DAY))
    assert_equal(0, s.calc_mean('2015-04-01'))
    # test for simple period
    assert_equal(1440.0, s.calc_mean('2015-05-02'))
    # incremental calculation from same start time
    assert_equal(1440.0, s.calc_mean('2015-05-03'))
    assert_equal(1440.0, s.calc_mean('2015-05-04 12:00'))
    # incremental calculation with different start time
    assert_equal(1440.0, s.calc_mean('2015-05-8'))
    # try to calculate a previous period
    assert_throws(:mean_fails) { s.calc_mean('2015-05-03 08:00') }
    # test for simple period 1/5 => 60, 2/5 => 70, 3/5 => 10, ...
    wday = Node.find_by_title(:wday)
    s = Stat.create(node: wday, stat: Stat::DAILY, period: Stat.from_period(6, Stat::P_DAY))
    assert_equal(1440.0, s.calc_mean('2015-05-02'))
    assert_equal(1560.0, s.calc_mean('2015-05-03'))
    # test for simple period, discard previous calculation
    assert_equal(880.0, s.calc_mean('2015-05-08'))
    # with where clause
    s1 = Stat.create(node: fixed60, stat: Stat::DAILY, period: Stat.from_period(3, Stat::P_DAY), where_clause: :F1)
    s2 = Stat.create(node: fixed60, stat: Stat::DAILY, period: Stat.from_period(3, Stat::P_DAY), where_clause: :F2)
    assert_equal(0.0, s1.calc_mean('2015-05-03'))
    assert_equal(219.66666666666666, s1.calc_mean('2015-05-05'))
    assert_equal(1220.0, s2.calc_mean('2015-05-05'))
    assert_equal(439.33333333333333, s1.calc_mean('2015-05-06'))
    assert_equal(1000.0, s2.calc_mean('2015-05-06'))
    # FIXME verify the 2 below
    assert_equal(633.7142857142857, s1.calc_mean('2015-05-07 12:00'))
    assert_equal(805.4285714285714, s2.calc_mean('2015-05-07 12:00'))
  end

  test "hourly mean" do
    assert_equal(1875.7575757575758, Stat.hourly_mean(Node.find_by_title(:triang), '2015-08-03 1:30'))
    assert_equal(60.0, Stat.hourly_mean(Node.find_by_title(:fixed60), '2015-05-01 1:30'))
    assert_equal(60.0, Stat.hourly_mean(Node.find_by_title(:fixed60), '2015-05-01 12:00'))
    assert_in_delta(60.0, Stat.hourly_mean(Node.find_by_title(:fixed60), '2015-05-05'))
    assert_equal(40.0, Stat.hourly_mean(Node.find_by_title(:wday), '2015-05-15'))
    assert_in_delta(41.18411375337093, Stat.hourly_mean(Node.find_by_title(:wday), '2015-05-18'))
    assert_equal(1015.0704910063199, Stat.hourly_mean(Node.find_by_title(:hourly), '2015-05-01 04:00', Stat.from_period(24, Stat::P_HOUR)))
    assert_equal(1115.0, Stat.hourly_mean(Node.find_by_title(:hourly), '2015-05-02 00:00'))
  end
  test "daily mean" do
    assert_equal(1440.0, Stat.daily_mean(Node.find_by_title(:fixed60), '2015-05-01 12:00'))
    assert_equal(1440.0, Stat.daily_mean(Node.find_by_title(:fixed60), '2015-05-02'))
    assert_equal(1440.0, Stat.daily_mean(Node.find_by_title(:fixed60), '2015-05-02 21:00', Stat.from_period(1, Stat::P_DAY)))
    assert_equal(1440.0, Stat.daily_mean(Node.find_by_title(:fixed60), '2015-05-10'))
    assert_equal(960.0, Stat.daily_mean(Node.find_by_title(:wday), '2015-05-15'))
    assert_in_delta(988.4187300809022, Stat.daily_mean(Node.find_by_title(:wday), '2015-05-18'))
  end

  test "monthly mean" do
    assert_equal(14400.0, Stat.monthly_mean(Node.find_by_title(:fixed20), '2015-02-15'))
    # assert_equal(47520.0, monthly_mean(Node.find_by_title(:monthly)))
    assert_equal(14400.000000000002, Stat.monthly_mean(Node.find_by_title(:fixed20), '2015-02-04', Stat.from_period(2, Stat::P_MONTH)))
    assert_equal(46740.95296932954, Stat.monthly_mean(Node.find_by_title(:monthly), '2015-07-01', Stat.from_period(3, Stat::P_MONTH)))
  end

  test "yearly mean" do
    assert_equal(525600.0, Stat.yearly_mean(Node.find_by_title(:fixed60), '2015-05-10'))
    assert_equal(568681.5944601761, Stat.yearly_mean(Node.find_by_title(:monthly), '2015-07-01'))
    assert_equal(525600.0, Stat.yearly_mean(Node.find_by_title(:monthly), '2015-06-01', Stat.from_period(1, Stat::P_YEAR)))
  end

  test "hourly grouped mean" do
    Time.zone = "Europe/Rome"
    n = Node.find_by_title(:triang)
    p = Stat.from_period(23, Stat::P_HOUR)
    # single interval, start from beginning
    assert_equal([[0, 3551.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1899.8678996036988, 0.42055555555555557], [12, 0.0, 0.0], [13, 0.0, 0.0], [14, 0.0, 0.0], [15, 0.0, 0.0], [16, 0.0, 0.0], [17, 0.0, 0.0], [18, 0.0, 0.0], [19, 0.0, 0.0], [20, 0.0, 0.0], [21, 0.0, 0.0], [22, 0.0, 0.0], [23, 0.0, 0.0]], Stat.hourly_grouped_mean(n, '2015-08-01 11:25:14', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # concatenate to previous result, no removing
    assert_equal([[0, 3551.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1900.0000000000005, 1.0000000000000004], [12, 1750.0, 1.0], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1300.0, 1.0], [16, 1150.0, 1.0], [17, 1000.0, 1.0], [18, 850.0, 1.0], [19, 700.0, 1.0], [20, 549.9165275459098, 0.9983333333333333], [21, 0.0, 0.0], [22, 0.0, 0.0], [23, 0.0, 0.0]], Stat.hourly_grouped_mean(n, '2015-08-01 21:00', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # reuse previous results, removing previous interval
    assert_equal([[0, 100.0, 1.0], [1, 250.0, 1.0], [2, 400.0, 1.0], [3, 550.0, 1.0], [4, 700.0, 1.0], [5, 850.0, 1.0], [6, 1000.0, 1.0], [7, 1150.0, 1.0], [8, 1300.0, 1.0], [9, 1450.0, 1.0], [10, 1600.0, 1.0], [11, 1737.9310344827625, 0.016111111111111076], [12, 1750.4862461794944, 0.9997222222222222], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1300.0, 1.0], [16, 1150.0, 1.0], [17, 1000.0, 1.0], [18, 850.0, 1.0], [19, 700.0, 1.0], [20, 550.0000000000001, 0.9999999999999997], [21, 400.0, 1.0], [22, 250.0, 1.0], [23, 100.0, 1.0]], Stat.hourly_grouped_mean(n, '2015-08-02 11:00:59', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # concatenate to previous result, removing initial interval
    assert_equal([[0, 3550.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.4347826086955, 0.7666666666666667], [8, 1300.3612114476243, 0.9997222222222222], [9, 1450.0, 1.0], [10, 1600.0, 1.0], [11, 1750.0, 1.0], [12, 1900.0, 1.0], [13, 2050.0, 1.0], [14, 2200.0, 1.0], [15, 2350.0, 1.0], [16, 2500.0, 1.0], [17, 2650.0, 1.0], [18, 2800.0, 1.0], [19, 2950.0, 1.0], [20, 3100.0, 1.0], [21, 3250.0, 1.0], [22, 3400.0, 1.0], [23, 3549.0, 1.0]], Stat.hourly_grouped_mean(n, '2015-08-03 07:46', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # single interval, day incomplete, discard previous result
    assert_equal([[0, 3550.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1900.0, 1.0], [12, 1750.0, 1.0], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1303.4482758620718, 0.016111111111111076], [16, 2500.0, 1.0], [17, 2650.0, 1.0], [18, 2800.0, 1.0], [19, 2950.0, 1.0], [20, 3100.0, 1.0], [21, 3250.0, 1.0], [22, 3400.0, 1.0], [23, 3550.0, 1.0]], Stat.hourly_grouped_mean(n, '2015-08-05 15:00:59', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # discard previous result
    assert_equal([[0, 3550.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1900.0, 1.0], [12, 1750.0, 1.0], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1300.0, 1.0], [16, 1150.0, 1.0], [17, 1010.5263157894716, 0.015833333333333366], [18, 2800.0, 1.0], [19, 2950.0, 1.0], [20, 3100.0, 1.0], [21, 3250.0, 1.0], [22, 3400.0, 1.0], [23, 3550.0, 1.0]], Stat.hourly_grouped_mean(n, '2015-08-07 17:00:59', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # single interval, no period, start from beginning
    assert_equal([[0, 3551.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1900.0, 1.0], [12, 1750.0, 1.0], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1300.0, 1.0], [16, 1150.0, 1.0], [17, 993.1034482758643, 0.016111111111111076], [18, 0.0, 0.0], [19, 0.0, 0.0], [20, 0.0, 0.0], [21, 0.0, 0.0], [22, 0.0, 0.0], [23, 0.0, 0.0]], Stat.hourly_grouped_mean(n, '2015-08-01 17:00:59').map {|k,v| [k, v.mean, v.sum_weight]})
    # concatenate to previous result, no period, no removing
    assert_equal([[0, 3551.0, 1.0], [1, 3400.0, 1.0], [2, 3250.0, 1.0], [3, 3100.0, 1.0], [4, 2950.0, 1.0], [5, 2800.0, 1.0], [6, 2650.0, 1.0], [7, 2500.0, 1.0], [8, 2350.0, 1.0], [9, 2200.0, 1.0], [10, 2050.0, 1.0], [11, 1900.0, 1.0], [12, 1750.0, 1.0], [13, 1600.0, 1.0], [14, 1450.0, 1.0], [15, 1300.0, 1.0], [16, 1150.0, 1.0], [17, 1000.0, 1.0], [18, 850.0, 1.0], [19, 700.0, 1.0], [20, 550.0, 1.0], [21, 400.0, 1.0], [22, 249.906191369606, 0.2961111111111111], [23, 0.0, 0.0]], Stat.hourly_grouped_mean(n, '2015-08-01 22:17:59').map {|k,v| [k, v.mean, v.sum_weight]})
    # concatenate to previous result, no period, no removing
    assert_equal([[0, 2400.3333333333335, 3.0], [1, 2350.0, 3.0], [2, 2289.315478977432, 2.966388888888889], [3, 1825.0, 2.0], [4, 1825.0, 2.0], [5, 1825.0, 2.0], [6, 1825.0, 2.0], [7, 1825.0, 2.0], [8, 1825.0, 2.0], [9, 1825.0, 2.0], [10, 1825.0, 2.0], [11, 1825.0, 2.0], [12, 1825.0, 2.0], [13, 1825.0, 2.0], [14, 1825.0, 2.0], [15, 1825.0, 2.0], [16, 1825.0, 2.0], [17, 1825.0, 2.0], [18, 1825.0, 2.0], [19, 1825.0, 2.0], [20, 1825.0, 2.0], [21, 1825.0, 2.0], [22, 1825.0000000000002, 1.9999999999999998], [23, 1824.5, 2.0]], Stat.hourly_grouped_mean(n, '2015-08-03 02:57:59').map {|k,v| [k, v.mean, v.sum_weight]})
    # concatenate to previous result, no period, no removing
    assert_equal([[0, 1825.2499999999973, 4.0], [1, 1825.0, 4.0], [2, 1824.9999999999982, 4.000000000000001], [3, 1825.0, 4.0], [4, 1825.0, 4.0], [5, 1825.0, 4.0], [6, 1825.0, 4.0], [7, 1825.0, 4.0], [8, 1825.0, 4.0], [9, 1825.0, 4.0], [10, 1825.0, 4.0], [11, 1825.0, 4.0], [12, 1825.0, 4.0], [13, 1825.0, 4.0], [14, 1825.0, 4.0], [15, 1825.0, 4.0], [16, 1825.0, 4.0], [17, 1825.0, 4.0], [18, 1825.0, 4.0], [19, 1825.0, 4.0], [20, 1825.0, 4.0], [21, 1825.0, 4.0], [22, 1825.0, 4.0], [23, 1824.75, 4.0]], Stat.hourly_grouped_mean(n, '2015-08-05 00:00:00').map {|k,v| [k, v.mean, v.sum_weight]})
  end

  test "weekly grouped mean" do
    Time.zone = "Europe/Rome"
    n = Node.find_by_title(:fixed60)
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 1440.0, 1.0], [6, 0.0, 0.0]], Stat.weekly_grouped_mean(n, '2015-05-02').map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 1440.0, 2.0], [6, 1440.0, 1.5]], Stat.weekly_grouped_mean(n, '2015-05-09 12:00').map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 1440.0, 2.0], [6, 1440.0, 1.9986111111111111]], Stat.weekly_grouped_mean(n, '2015-05-09 23:58:00').map {|k,v| [k, v.mean, v.sum_weight]})
    ############
    p = Stat.from_period(6, Stat::P_DAY)
    assert_equal([[0, 1440.0, 1.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 1440.0, 1.0], [6, 1440.0, 1.0]], Stat.weekly_grouped_mean(n, '2015-05-04', p).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 0.0, 0.0], [6, 1440.0, 1.0]], Stat.weekly_grouped_mean(n, '2015-05-08', p).map {|k,v| [k, v.mean, v.sum_weight]})
    ###########
    p = Stat.from_period(5, Stat::P_DAY)
    assert_equal([[0, 1440.0, 0.5569444444444445], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 1440.0, 1.0], [6, 1440.0, 1.0]], Stat.weekly_grouped_mean(n, '2015-05-03 13:22:25', p).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0000000000002, 0.9999999999999996], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 0.0, 0.0], [6, 0.0, 0.0]], Stat.weekly_grouped_mean(n, '2015-05-08', p).map {|k,v| [k, v.mean, v.sum_weight]})
    ###########
    p = Stat.from_period(3, Stat::P_DAY)
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 1440.0, 1.0], [6, 0.0, 0.0]], Stat.weekly_grouped_mean(n, '2015-05-02', p).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0]], Stat.weekly_grouped_mean(n, '2015-05-06', p).map {|k,v| [k, v.mean, v.sum_weight]})
    # assert_equal([[0, 0.24], [1, 0.48], [2, 0.72], [3, 0.96], [4, 1.2], [5, 1.44], [6, 1.68]], weekly(Node.find_by_title(:wday)))
    # assert_equal([[0, 0.24], [1, 0.48], [2, 0.72], [3, 0.96], [4, 1.2], [5, 1.44], [6, 1.68]], weekly(Node.find_by_title(:wday), '2015-05-08', 7))
  end

  test "monthly grouped mean" do
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 1440.0, 1.0], [6, 1440.0, 1.0], [7, 1440.0, 1.0], [8, 1440.0, 0.9993055555555556], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0], [12, 0.0, 0.0], [13, 0.0, 0.0], [14, 0.0, 0.0], [15, 0.0, 0.0], [16, 0.0, 0.0], [17, 0.0, 0.0], [18, 0.0, 0.0], [19, 0.0, 0.0], [20, 0.0, 0.0], [21, 0.0, 0.0], [22, 0.0, 0.0], [23, 0.0, 0.0], [24, 0.0, 0.0], [25, 0.0, 0.0], [26, 0.0, 0.0], [27, 0.0, 0.0], [28, 0.0, 0.0], [29, 0.0, 0.0], [30, 0.0, 0.0]], Stat.monthly_grouped_mean(Node.find_by_title(:fixed60), '2015-05-10').map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1440.0, 1.0], [1, 1440.0, 1.0], [2, 1440.0, 1.0], [3, 1440.0, 1.0], [4, 1440.0, 1.0], [5, 1440.0, 1.0], [6, 1440.0, 1.0], [7, 1440.0, 1.0], [8, 1440.0, 1.0], [9, 1440.0, 1.0], [10, 1440.0, 1.0], [11, 1440.0, 1.0], [12, 1440.0, 1.0], [13, 1440.0, 1.0], [14, 1440.0, 1.0], [15, 1440.0, 1.0], [16, 1440.0, 1.0], [17, 1440.0, 1.0], [18, 1440.0, 1.0], [19, 1440.0, 1.0], [20, 1440.0, 1.0], [21, 1440.0, 1.0], [22, 1440.0, 1.0], [23, 1440.0, 1.0], [24, 1440.0, 1.0], [25, 1440.0, 1.0], [26, 1440.0, 1.0], [27, 1440.0, 1.0], [28, 1440.0, 1.0], [29, 1440.0, 1.0], [30, 1440.0, 1.0]], Stat.monthly_grouped_mean(Node.find_by_title(:monthly), '2015-06-01', Stat.from_period(1, Stat::P_MONTH)).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1680.0, 1.0], [1, 1680.0, 1.0], [2, 1680.0, 1.0], [3, 1680.0, 1.0], [4, 1680.0, 1.0], [5, 1680.0, 1.0], [6, 1680.0, 1.0], [7, 1680.0, 1.0], [8, 1680.0, 1.0], [9, 1680.0, 1.0], [10, 1680.0, 1.0], [11, 1680.0, 1.0], [12, 1680.0, 1.0], [13, 1680.0, 1.0], [14, 1680.0, 1.0], [15, 1680.0, 1.0], [16, 1680.0, 1.0], [17, 1680.0, 1.0], [18, 1680.0, 1.0], [19, 1680.0, 1.0], [20, 1680.0, 1.0], [21, 1680.0, 1.0], [22, 1680.0, 1.0], [23, 1680.0, 1.0], [24, 1680.0, 1.0], [25, 1680.0, 1.0], [26, 1680.0, 1.0], [27, 1680.0, 1.0], [28, 1680.0, 1.0], [29, 1680.011117802381, 0.9993981481481482], [30, 1440.0, 1.0]], Stat.monthly_grouped_mean(Node.find_by_title(:monthly), '2015-07-15', Stat.from_period(1, Stat::P_MONTH)).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 1560.0, 2.0], [1, 1560.0, 2.0], [2, 1560.0, 2.0], [3, 1560.0, 2.0], [4, 1560.0, 2.0], [5, 1560.0, 2.0], [6, 1560.0, 2.0], [7, 1560.0, 2.0], [8, 1560.0, 2.0], [9, 1560.0, 2.0], [10, 1560.0, 2.0], [11, 1560.0, 2.0], [12, 1560.0, 2.0], [13, 1560.0, 2.0], [14, 1560.0, 2.0], [15, 1560.0, 2.0], [16, 1560.0, 2.0], [17, 1560.0, 2.0], [18, 1560.0, 2.0], [19, 1560.0, 2.0], [20, 1560.0, 2.0], [21, 1560.0, 2.0], [22, 1560.0, 2.0], [23, 1560.0, 2.0], [24, 1560.0, 2.0], [25, 1560.0, 2.0], [26, 1560.0, 2.0], [27, 1560.0, 2.0], [28, 1560.0, 2.0], [29, 1559.9694352467177, 1.9993981481481482], [30, 1440.0, 1.0]], Stat.monthly_grouped_mean(Node.find_by_title(:monthly), '2015-07-01').map {|k,v| [k, v.mean, v.sum_weight]})
  end

  test "yearly grouped mean" do
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 44640.0, 1.0], [5, 53874.793103448275, 0.9354838709677419], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.yearly_grouped_mean(Node.find_by_title(:monthly), '2015-07-01').map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 50216.125, 0.25806451612903225], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.yearly_grouped_mean(Node.find_by_title(:fixed60), '2015-05-10').map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 44640.0, 1.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.yearly_grouped_mean(Node.find_by_title(:monthly), '2015-06-01', Stat.from_period(1, Stat::P_YEAR)).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 53874.793103448275, 0.9354838709677419], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.yearly_grouped_mean(Node.find_by_title(:monthly), '2015-08-01', Stat.from_period(2, Stat::P_MONTH)).map {|k,v| [k, v.mean, v.sum_weight]})
  end

  test "daily per month grouped mean"  do
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 1440.0, 8.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-09', Stat.from_period(6, Stat::P_MONTH)).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 480.0, 9.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 480.0, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-10').map {|k,v| [k, v.mean, v.sum_weight]})
  end

  test "daily_slot_per_month grouped mean" do
    # assert_equal([[5, 0.66]], daily_per_month(Node.find_by_title(:fixed60), q_f1, '2015-05-04', '2015-05-09'))
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 204.60710441334768, 4.5159722222222225], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-05 12:23', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 1235.6143318468398, 4.5159722222222225], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-05 12:23', nil, :F2).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 264.20000000000033, 4.999999999999997], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-06 00:00', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 1176.2, 4.999999999999997], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-06 00:00', nil, :F2).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 383.2550639927441, 6.8909722222222225], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-07 21:23', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 412.6249999999999, 7.999999999999997], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-09', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 1027.75, 8.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 0.0, 0.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed60), '2015-05-09', nil, :F2).map {|k,v| [k, v.mean, v.sum_weight]})

    assert_equal([[0, 122.22222222222223, 9.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 141.93548387096774, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-10', Stat.from_period(3, Stat::P_DAY_MONTH), :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 357.8888888888889, 9.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 338.06451612903226, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-10', Stat.from_period(3, Stat::P_DAY_MONTH), :F2).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 0.0, 0.5229166666666667], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 141.93548387096774, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-1 12:34', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 481.91235059760953, 0.5229166666666667], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 338.06451612903226, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-1 12:34', nil, :F2).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 122.22222222222223, 9.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 141.935483870968, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-10', nil, :F1).map {|k,v| [k, v.mean, v.sum_weight]})
    assert_equal([[0, 358.00000000000006, 9.0], [1, 0.0, 0.0], [2, 0.0, 0.0], [3, 0.0, 0.0], [4, 0.0, 0.0], [5, 0.0, 0.0], [6, 0.0, 0.0], [7, 0.0, 0.0], [8, 0.0, 0.0], [9, 0.0, 0.0], [10, 0.0, 0.0], [11, 338.064516129032, 31.0]], Stat.daily_per_month_grouped_mean(Node.find_by_title(:fixed20), '2015-01-10', nil, :F2).map {|k,v| [k, v.mean, v.sum_weight]})
  end

  test "incremental stat" do
    # assert(Stat.daily_mean(Node.find_by_title(:real), '2015-05-01 06:44:56') > 0)
    # assert(Stat.daily_mean(Node.find_by_title(:real), '2015-08-12 15:23:11') > 0)
    # assert(Stat.daily_mean(Node.find_by_title(:real), '2015-10-21 02:56:23') > 0)
    #
    # assert(Stat.hourly_grouped_mean(Node.find_by_title(:real), '2015-05-05 12:25:14', Stat.from_period(23, Stat::P_HOUR)).all? {|k,v| v.mean >= 0 && v.sum_weight >= 0 } )
    # assert(Stat.hourly_grouped_mean(Node.find_by_title(:real), '2015-05-06 00:11:56', Stat.from_period(23, Stat::P_HOUR)).all? {|k,v| v.mean >= 0 && v.sum_weight >= 0 } )
  end

end