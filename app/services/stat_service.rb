
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

  def self.STAT_TIME(i)
    case i
    when HOURLY, GROUP_BY_HOUR then 3600.0
    when DAILY, GROUP_BY_WDAY then 86400.0
    when MONTHLY, GROUP_BY_MONTH then 2592000.0
    when YEARLY, GROUP_BY_DAILY_PER_MONTH then 31536000.0
    end
  end

  def self.GROUP_SIZE(i)
    case i
    when GROUP_BY_HOUR then 24
    when GROUP_BY_WDAY then 7
    when GROUP_BY_DAY_OF_MONTH then 31
    when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then 12
    end
  end

  def self.GROUPING(i)
    case i
    when GROUP_BY_HOUR then "extract(hour from timezone('#{tz}', pulse_time))::integer"
    when GROUP_BY_WDAY then "extract(dow from timezone('#{tz}', pulse_time))::integer"
    when GROUP_BY_DAY_OF_MONTH then "extract(day from timezone('#{tz}', pulse_time))::integer - 1"
    when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then "extract(month from timezone('#{tz}', pulse_time))::integer - 1"
    end
  end

  def self.TIME_GROUPING(i, t)
    case i
    when GROUP_BY_HOUR then t.hour
    when GROUP_BY_WDAY then t.wday
    when GROUP_BY_DAY_OF_MONTH then t.day - 1
    when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then t.month - 1
    end
  end

  def self.DIFF_TIME(i, t)
    case i
    when GROUP_BY_HOUR then (t - t.change(min: 0)).to_f / 3600.0 # difference from start of hour
    when GROUP_BY_WDAY, GROUP_BY_DAY_OF_MONTH, GROUP_BY_DAILY_PER_MONTH then (t - t.change(hour: 0)).to_f / 86400.0 # difference from start of day
    when GROUP_BY_MONTH then (t - t.change(day: 1)).to_f / 2678400.0 # difference from first day of month
    end
  end

  def self.WHERE_CLAUSE(q)
    q_f1 = "(extract(hour from timezone('#{tz}', pulse_time)) >= 8 and extract(hour from timezone('#{tz}', pulse_time)) < 19 and extract(dow from timezone('#{tz}', pulse_time)) between 1 and 5 and (extract(month from timezone('#{tz}', pulse_time)), extract(day from timezone('#{tz}', pulse_time))) not in ((1,1),(1,6),(4,25),(5,1),(6,2),(8,15),(11,1),(12,8),(12,25),(12,26)))"
    case q
    when :f1 then q_f1
    when :f2 then "not (#{q_f1})"
    end
  end

  def self.WHERE_CLAUSE_EXPR(q, t)
    expr = t.hour >= 8 && t.hour < 19 and [[1,1],[1,6],[4,25],[5,1],[6,2],[8,15],[11,1],[12,8],[12,25],[12,26]].include?([t.month, t.day])
    case q
    when :f1 then expr
    when :f2 then !expr
    end
  end

  def self.SELECT(i)
    case i
    when GROUP_BY_HOUR then "count(pulse_time) as sum_val, #{GROUPING(i)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
    when GROUP_BY_WDAY then "count(pulse_time) sum_val, #{GROUPING(i)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
    when GROUP_BY_DAY_OF_MONTH then "count(pulse_time) as sum_val, #{GROUPING(i)} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', pulse_time))/86400.0)))::float as sum_weight"
    when GROUP_BY_MONTH then "count(pulse_time) as sum_val, #{GROUPING(i)} as group_by, count(distinct(extract(year from timezone('#{tz}', pulse_time)) * 12 + extract(month from timezone('#{tz}', pulse_time))))::float as sum_weight"
    when GROUP_BY_DAILY_PER_MONTH then "count(pulse_time) as sum_val, #{GROUPING(i)} as group_by, count(distinct(extract(day from timezone('#{tz}', pulse_time))))::float as sum_weight"
    end
  end

  def self.tz
    Time.zone.now.formatted_offset
  end

  def _raw_mean(current_node, stat, t0, t1, where_clause = nil)
    period = StatService.STAT_TIME(stat)
    # dt = t1 - t0
    # dt = period < dt ? 0.0 + dt / period : 1
    dt = 0.0 + (t1 - t0) / period
    # pp t0, t1, dt
    q = Pulse.where(node: current_node).where('pulse_time >= ? and pulse_time <= ?', t0, t1)
    q = q.where(where_clause) unless where_clause.nil?
    v = q.count()
    return v > 0 ? (v-1.0)/dt : 0.0, dt
  end

  def _mean(current_node, stat, end_period, period = nil, where_clause = nil)
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
      #   date.in_time_zone
      else
        raise "unable to convert #{date}:#{date.class} to date"
    end
  end

  def verify_period(current_node, p1, period)
    # p1 = p1.nil? ? self.where(node: current_node).maximum(:pulse_time) : convert_date(p1)
    p1 = p1.nil? ? Time.zone.now : convert_date(p1)
    return nil, nil if p1.nil?
    mm = Pulse.where(node: current_node)
    mm = mm.where("pulse_time + interval '? day' >= ?", period, p1) unless period.nil?
    mm = mm.where('pulse_time <= ?', p1).select('min(pulse_time) as min_t, max(pulse_time) as max_t')
    # min = mm.minimum(:pulse_time)
    # return nil, nil if min.nil?
    return nil, nil if mm[0].min_t.nil?
    return [mm[0].min_t, mm[0].max_t]
    # return [min, p1]
  end

  def _raw_mean_grouped(current_node, stat, t0, t1, where_clause = nil)
    subq = Pulse.where(node: current_node)
    subq = subq.where(where_clause) unless where_clause.nil?
    subq = subq.group(StatService.GROUPING(stat)).select(StatService.SELECT(stat)).where("pulse_time >= ? and pulse_time <= ?", t0, t1)
    Pulse.from(subq, :pulses).select(:sum_val, :sum_weight, :group_by)
  end

  def _do_raw_mean_grouped(current_node, stat, p0, p1, where_clause = nil)
    res = _raw_mean_grouped(current_node, stat, p0, p1)
    rv = res.index_by(&:group_by)
    unless where_clause.nil?
      res1 = _raw_mean_grouped(current_node, stat, p0, p1, where_clause)
      rv1 = res1.index_by(&:group_by)
      # pp rv1
      rv.each {|g, v| v.sum_val = rv1[g].nil? ? 0.0 : rv1[g].sum_val }
    end
    g = StatService.TIME_GROUPING(stat, p0)
    unless rv[g].nil?
      # adjust sum_weight for initial interval
      ss_old = rv[g].sum_weight
      rv[g].sum_weight -= StatService.DIFF_TIME(stat, p0)
      # pp "--",p0, p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
    end
    g = StatService.TIME_GROUPING(stat, p1)
    unless rv[g].nil?
      ss_old = rv[g].sum_weight
      rv[g].sum_weight += StatService.DIFF_TIME(stat, p1) - 1.0
      rv[g].sum_val -= 1 if where_clause.nil? #|| StatService.WHERE_CLAUSE_EXPR(stat, p1)
      # pp "++", p0,p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
    end
    rv
  end

  def _grouped_mean(current_node, stat, end_period, period = nil, where_clause = nil)
    p0, p1 = verify_period(current_node, end_period, period)
    # retrieve last calculated mean, throw exception if last date for calculated mean is greater than requested date
    s = Stat.current_stat_mean(current_node, stat, period, where_clause)
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
      rv = _do_raw_mean_grouped(current_node, stat, s.start_time, p0, where_clause)
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
    rv = _do_raw_mean_grouped(current_node, stat, s.end_time, p1, where_clause)
    # add extracted values to stat_values
    sv.each do |g, v|
      m0, s0 = rv[g].nil? ? [0.0, 0.0] : [rv[g].sum_val, rv[g].sum_weight]
      if v.sum_weight == 0
        m1, s1 = s0 > 0 ? m0/s0 : 0.0, s0
      else
        s1 = s0 + v.sum_weight
        m1 = (m0 + v.mean * v.sum_weight) / s1
      end
      # FIXME
      # raise "fail #{v}" if v.mean < 0 || v.sum_weight < 0
      v.update(mean: m1, sum_weight: s1)
    end
    # save new starting and ending periods
    s.update(start_time: p0, end_time: p1)
    sv
  end

  # def self.daily_mean(current_node, start_period = nil, end_period = nil, where_clause = nil)
  def daily_mean(current_node, end_period = nil, period = nil, where_clause = nil)
    _mean(current_node, DAILY, end_period, period, where_clause)
  end

  def hourly_mean(current_node, end_period = nil, period = nil)
    _mean(current_node, HOURLY, end_period, period)
  end

  def monthly_mean(current_node, end_period = nil, period = nil)
    _mean(current_node, MONTHLY, end_period, period)
  end

  def yearly_mean(current_node, end_period = nil, period = nil)
    _mean(current_node, YEARLY, end_period, period)
  end

  def weekly(current_node, end_period = nil, period = nil)
    _grouped_mean(current_node, GROUP_BY_WDAY, end_period, period)
  end

  def daily(current_node, end_period = nil, period = nil)
    _grouped_mean(current_node, GROUP_BY_HOUR, end_period, period)
  end

  def monthly(current_node, end_period = nil, period = nil)
    _grouped_mean(current_node, GROUP_BY_DAY_OF_MONTH, end_period, period)
  end

  def yearly(current_node, end_period = nil, period = nil)
    _grouped_mean(current_node, GROUP_BY_MONTH, end_period, period)
  end


  def daily_per_month(current_node, end_period = nil, period = nil, where_clause = nil)
    _grouped_mean(current_node, GROUP_BY_DAILY_PER_MONTH, end_period, period, where_clause)
  end

  def daily_slot_per_month(current_node, end_period = nil, period = nil, where_clause)
    _grouped_mean(current_node, GROUP_BY_DAILY_PER_MONTH, end_period, period, where_clause)
  end

end