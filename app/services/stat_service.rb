
module StatService

  HOURLY = 0
  DAILY = 1
  MONTHLY = 2
  YEARLY = 3
  GROUP_BY_HOUR = 4
  GROUP_BY_WDAY = 5
  GROUP_BY_DAY_OF_MONTH = 6
  GROUP_BY_MONTH = 7
  GROUP_BY_DAILY_PER_MONTH = 8

  STAT_TIME = [
      3600.0,
      86400.0,
      2592000.0,
      31536000.0,
  ]

  GROUP_SIZE = [24, 7, 31, 12, 12]

  def GROUPING(i)
  	case i
  	when 0
  		"extract(hour from timezone('#{tz}', pulse_time))::integer"
  	when 1
  		"extract(dow from timezone('#{tz}', pulse_time))::integer"
  	when 2
  		"extract(day from timezone('#{tz}', pulse_time))::integer - 1"
  	when 3
  		"extract(month from timezone('#{tz}', pulse_time))::integer - 1"
  	when 4
  		"extract(month from timezone('#{tz}', pulse_time))::integer - 1"
  	end
  end

  TIME_GROUPING = [
      ->(t) { t.hour },
      ->(t) { t.wday },
      ->(t) { t.day - 1 },
      ->(t) { t.month - 1 },
      ->(t) { t.month - 1 }
  ]

  DIFF_TIME = [
      ->(t) { (t - t.change(min: 0)).to_f / 3600.0 }, # difference from start of hour
      ->(t) { (t - t.change(hour: 0)).to_f / 86400.0 }, # difference from start of day
      ->(t) { (t - t.change(hour: 0)).to_f / 86400.0 }, # same
      ->(t) { (t - t.change(day: 1)).to_f / 2678400.0 }, # difference from first day of month
      ->(t) { (t - t.change(hour: 0)).to_f / 86400.0 } # difference from start of day
  ]

  def WHERE_CLAUSE(q)
  	q_f1 = "(extract(hour from timezone('#{tz}', pulse_time)) > 8 and extract(hour from timezone('#{tz}', pulse_time)) <= 19 and extract(dow from timezone('#{tz}', pulse_time)) between 1 and 5 and (extract(month from timezone('#{tz}', pulse_time)), extract(day from timezone('#{tz}', pulse_time))) not in ((1,1),(1,6),(4,25),(5,1),(6,2),(8,15),(11,1),(12,8),(12,25),(12,26)))"
  	case q
  	when :f1
			q_f1
		when :f2			
			"not (#{q_f1})"
		end
	end

  def SELECT(i)
  	case i
  	when 0
  	"count(pulse_time) as sum_val, #{GROUPING(0)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
  when 1
  	"count(pulse_time) sum_val, #{GROUPING(1)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
  when 2  		
  	"count(pulse_time) as sum_val, #{GROUPING(2)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
  when 3
  	"count(pulse_time) as sum_val, #{GROUPING(3)} as group_by, count(distinct(extract(year from timezone('#{tz}', pulse_time)) * 12 + extract(month from timezone('#{tz}', pulse_time))))::float as sum_weight"
  when 4
  	"count(pulse_time) as sum_val, #{GROUPING(4)} as group_by, count(distinct(extract(day from timezone('#{tz}', pulse_time))))::float as sum_weight"
  	end
  end

  def tz
    Time.zone.now.formatted_offset
  end

  def _raw_mean(current_node, stat, t0, t1, where_clause = nil)
    period = STAT_TIME[stat]
    # dt = t1 - t0
    # dt = period < dt ? 0.0 + dt / period : 1
    dt = 0.0 + (t1 - t0) / period
    # pp t0, t1, dt
    q = Pulse.where(node: current_node).where('pulse_time >= ? and pulse_time <= ?', t0, t1)
    q = q.where(where_clause) unless where_clause.nil?
    v = q.count()
    return v > 0 ? (v-1.0)/dt : 0.0, dt
  end

  def _raw_mean_grouped(current_node, stat, t0, t1)
  	stat_idx = stat - GROUP_BY_HOUR
    subq = Pulse.where(node: current_node).group(GROUPING(stat_idx)).select(SELECT(stat_idx)).where("pulse_time >= ? and pulse_time <= ?", t0, t1)
    Pulse.from(subq, :pulses).select(:sum_val, :sum_weight, :group_by)
  end

  def mean(current_node, stat, end_period, period = nil, where_clause = nil)
  	p0, p1 = verify_period(current_node, end_period, period)
    return 0.0 if p1.nil?
    # retrieve last calculated mean, throw exception if last date for calculated mean is greater than requested date
    s = Stat.current_stat_mean(current_node, stat, period, where_clause)
    throw :mean_fails if !s.end_time.nil? && s.end_time > p1
   	s.end_time = p0 if s.end_time.nil?
   	# s.end_time to nil means no data is available, return 0
   	return 0.0 if s.end_time.nil?
    if s.end_time < p1
    	if s.end_time <= p0
    		s.mean = 0.0
    		s.sum_weight = 0.0
    		s.end_time = p0
    	elsif !s.start_time.nil? && s.start_time < p0
    		m1, s1 = Pulse._raw_mean(current_node, stat, s.start_time, p0, where_clause)
    		s2 = s.sum_weight - s1
    		m2 = (s.mean * s.sum_weight - m1 * s1) / s2
    		s.mean = m2
    		s.sum_weight = s2
    	end
    	m0, s0 = Pulse._raw_mean(current_node, stat, s.end_time, p1, where_clause)
    	s1 = s0 + s.sum_weight
    	m1 = (m0 * s0 + s.mean * s.sum_weight) / s1
    	s.update(mean: m1, sum_weight: s1, start_time: p0, end_time: p1)
    end
    s.mean
  end

  def convert_date(date)
    case date
      when ActiveSupport::TimeWithZone
        date
      when Time
        date.in_time_zone
      when String
        Time.zone.parse(date)
      when Numeric
        Time.zone.at(date)
      # when Date, DateTime
      # 	date.in_time_zone
      else
        raise "unable to convert #{date}:#{date.class} to date"
    end
  end

  def verify_period(current_node, p1, period)
 		# p1 = p1.nil? ? self.where(node: current_node).maximum(:pulse_time) : convert_date(p1)
 		p1 = p1.nil? ? Time.zone.now : convert_date(p1)
 		return nil, nil if p1.nil?
    mm = self.where(node: current_node)
    mm = mm.where("pulse_time + interval '? day' >= ?", period, p1) unless period.nil?
    mm = mm.where('pulse_time <= ?', p1).select('min(pulse_time) as min_t, max(pulse_time) as max_t')
    # min = mm.minimum(:pulse_time)
    # return nil, nil if min.nil?
    return nil, nil if mm[0].min_t.nil?
    return [mm[0].min_t, mm[0].max_t]
    # return [min, p1]
  end

  # def self.verify_limit(current_node, p1)
  #   self.where(node: current_node).where('pulse_time < ?', p1).maximum(:pulse_time)
  # end

  def grouped_mean(current_node, stat, end_period, period = nil)
  	p0, p1 = verify_period(current_node, end_period, period)
    # retrieve last calculated mean, throw exception if last date for calculated mean is greater than requested date
    s = Stat.current_stat_mean(current_node, stat, period)
    return s.empty_values if p1.nil?
    # reset to 0 hours is needed to avoid period overlapping producing wrong counts; periods are defined in days
    # p1 = p1.change(hour: 0)
    throw :mean_fails if !s.end_time.nil? && s.end_time > p1
   	s.end_time = p0 if s.end_time.nil?
   	# what if end_time is nil?
   	# s.end_time to nil means no data is available, return zeroes
    return s.empty_values if s.end_time.nil?
  	sv = s.values
    return sv if s.end_time == p1
  	if s.end_time <= p0
  		sv.each do |g, v|
  			v.mean = 0.0
  			v.sum_weight = 0.0
  		end
  		s.end_time = p0
  	elsif !s.start_time.nil? && s.start_time < p0
  		# query from initial interval to be removed
  		rv = raw_mean_grouped(current_node, stat, s.start_time, p0)
  		# subtract extracted values from current stat_values
  		sv.each do |g, v|
 				m1, s1 = rv[g].nil? ? [0.0, 0.0] : [rv[g].sum_val, rv[g].sum_weight]
 				# throw :mean_fails if v.sum_weight == 0
 				if v.sum_weight > 0
 					s2 = v.sum_weight - s1
 					v.mean = (v.mean * v.sum_weight - m1) / s2
 					v.sum_weight = s2
 				end
  		end
  	end
  	# query additional data to be added to stat_values
  	rv = raw_mean_grouped(current_node, stat, s.end_time, p1)
  	# add extracted values to stat_values
  	sv.each do |g, v|
 			m0, s0 = rv[g].nil? ? [0.0, 0.0] : [rv[g].sum_val, rv[g].sum_weight]
  		if v.sum_weight == 0
  			m1, s1 = s0 > 0 ? m0/s0 : 0.0, s0
  		else
    		s1 = s0 + v.sum_weight
	  		m1 = (m0 + v.mean * v.sum_weight) / s1
  		end
 			v.update(mean: m1, sum_weight: s1)
  	end
  	# save new starting and ending periods
 		s.update(start_time: p0, end_time: p1)
    sv
  end

  def raw_mean_grouped(current_node, stat, p0, p1)
  	res = Pulse._raw_mean_grouped(current_node, stat, p0, p1)
  	rv = res.index_by(&:group_by)
  	stat_idx = stat - GROUP_BY_HOUR
  	g = TIME_GROUPING[stat_idx].call(p0)
  	unless rv[g].nil?
  		ss_old = rv[g].sum_weight
  		rv[g].sum_weight -= DIFF_TIME[stat_idx].call(p0)
  		# pp "--",p0,p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
  	end
  	g = TIME_GROUPING[stat_idx].call(p1)
  	unless rv[g].nil?
  		ss_old = rv[g].sum_weight
  		rv[g].sum_weight += DIFF_TIME[stat_idx].call(p1) - 1.0
  		rv[g].sum_val -= 1
  		# pp "++", p0,p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
  	end
  	rv
	end

end