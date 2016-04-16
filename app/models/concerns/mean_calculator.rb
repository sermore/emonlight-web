
module MeanCalculator
  extend ActiveSupport::Concern

  HOURLY = 0
  DAILY = 1
  MONTHLY = 2
  YEARLY = 3
  GROUP_BY_HOUR = 4
  GROUP_BY_WDAY = 5
  GROUP_BY_DAY_OF_MONTH = 6
  GROUP_BY_MONTH = 7
  GROUP_BY_DAILY_PER_MONTH = 8

  P_HOUR = 1
  P_DAY = 2
  P_MONTH = 3
  P_YEAR = 4
  P_DAY_MONTH = 5
  P_TYPES = [nil, 'hour', 'day', 'month', 'year', 'month']
  P_TRUNC = [nil, 'hour', 'day', 'month', 'year', 'day']

  def tz()
    # Time.zone.now.formatted_offset
    self.node.time_zone unless self.node.nil?
  end

  def STAT_TIME()
    case stat
      when HOURLY, GROUP_BY_HOUR then 3600.0
      when DAILY, GROUP_BY_WDAY, GROUP_BY_DAY_OF_MONTH then 86400.0
      when MONTHLY, GROUP_BY_MONTH then 2592000.0
      when YEARLY, GROUP_BY_DAILY_PER_MONTH then 31536000.0
    end
  end

  def GROUP_SIZE()
    case stat
      when GROUP_BY_HOUR then 24
      when GROUP_BY_WDAY then 7
      when GROUP_BY_DAY_OF_MONTH then 31
      when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then 12
    end
  end

  def GROUPING()
    case stat
      when GROUP_BY_HOUR then "extract(hour from timezone('#{tz}', timezone('UTC', pulse_time)))::integer"
      when GROUP_BY_WDAY then "extract(dow from timezone('#{tz}', timezone('UTC', pulse_time)))::integer"
      when GROUP_BY_DAY_OF_MONTH then "extract(day from timezone('#{tz}', timezone('UTC', pulse_time)))::integer - 1"
      when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then "extract(month from timezone('#{tz}', timezone('UTC', pulse_time)))::integer - 1"
    end
  end

  def TIME_GROUPING(t)
    case stat
      when GROUP_BY_HOUR then t.hour
      when GROUP_BY_WDAY then t.wday
      when GROUP_BY_DAY_OF_MONTH then t.day - 1
      when GROUP_BY_MONTH, GROUP_BY_DAILY_PER_MONTH then t.month - 1
    end
  end

  def DIFF_TIME(t)
    case stat
      when GROUP_BY_HOUR then (t - t.change(min: 0)).to_f / 3600.0 # difference from start of hour
      when GROUP_BY_WDAY, GROUP_BY_DAY_OF_MONTH, GROUP_BY_DAILY_PER_MONTH then (t - t.change(hour: 0)).to_f / 86400.0 # difference from start of day
      when GROUP_BY_MONTH then (t - t.change(day: 1)).to_f / 2678400.0 # difference from first day of month
    end
  end

  def SELECT()
    case stat
      when GROUP_BY_HOUR then "count(pulse_time) as sum_val, #{GROUPING()} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', timezone('UTC', pulse_time)))/86400.0)))::float as sum_weight"
      when GROUP_BY_WDAY then "count(pulse_time) sum_val, #{GROUPING()} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', timezone('UTC', pulse_time)))/86400.0)))::float as sum_weight"
      when GROUP_BY_DAY_OF_MONTH then "count(pulse_time) as sum_val, #{GROUPING()} as group_by, count(distinct(trunc(extract(epoch from timezone('#{tz}', timezone('UTC', pulse_time)))/86400.0)))::float as sum_weight"
      when GROUP_BY_MONTH then "count(pulse_time) as sum_val, #{GROUPING()} as group_by, count(distinct(extract(year from timezone('#{tz}', timezone('UTC', pulse_time))) * 12 + extract(month from timezone('#{tz}', timezone('UTC', pulse_time)))))::float as sum_weight"
      when GROUP_BY_DAILY_PER_MONTH then "count(pulse_time) as sum_val, #{GROUPING()} as group_by, count(distinct(extract(day from timezone('#{tz}', timezone('UTC', pulse_time)))))::float as sum_weight"
    end
  end

  def WHERE_CLAUSE()
    q_f1 = "(extract(hour from timezone('#{tz}', timezone('UTC', pulse_time))) >= 8 and extract(hour from timezone('#{tz}', timezone('UTC', pulse_time))) < 19 and extract(dow from timezone('#{tz}', timezone('UTC', pulse_time))) between 1 and 5 and (extract(month from timezone('#{tz}', timezone('UTC', pulse_time))), extract(day from timezone('#{tz}', timezone('UTC', pulse_time)))) not in ((1,1),(1,6),(4,25),(5,1),(6,2),(8,15),(11,1),(12,8),(12,25),(12,26)))"
    case where_clause
      when 'F1' then q_f1
      when 'F2' then "not (#{q_f1})"
    end
  end

  def calc_mean(time)
    p0, p1 = verify_period(time)
    return 0.0 if p1.nil?
    # retrieve last calculated mean, throw exception if last date for calculated mean is greater than requested date
    throw :mean_fails if !self.end_time.nil? && self.end_time > p1
    self.end_time = p0 if self.end_time.nil?
    # end_time to nil means no data is available, return 0
    return 0.0 if self.end_time.nil?
    if self.end_time < p1
      if self.end_time <= p0
        self.mean = 0.0
        self.sum_weight = 0.0
        self.end_time = p0
      elsif !self.start_time.nil? && self.start_time < p0
        m1, s1 = calc_raw_mean(self.start_time, p0)
        s2 = self.sum_weight - s1
        m2 = (self.mean * self.sum_weight - m1 * s1) / s2
        self.mean = m2
        self.sum_weight = s2
      end
      m0, s0 = calc_raw_mean(self.end_time, p1)
      s1 = s0 + self.sum_weight
      m1 = (m0 * s0 + self.mean * self.sum_weight) / s1
      update(mean: m1, sum_weight: s1, start_time: p0, end_time: p1)
    end
    self.mean
  end

  def calc_raw_mean(t0, t1)
    p = STAT_TIME()
    # dt = t1 - t0
    # dt = period < dt ? 0.0 + dt / period : 1
    dt = 0.0 + (t1 - t0) / p
    # pp t0, t1, dt
    q = Pulse.where(node: node).where('pulse_time >= ? and pulse_time <= ?', t0, t1)
    q = q.where(WHERE_CLAUSE()) unless where_clause.nil?
    v = q.count()
    return v > 0 ? (v-1.0)/dt : 0.0, dt
  end

  def grouped_mean(time)
    p0, p1 = verify_period(time)
    # retrieve last calculated mean, throw exception if last date for calculated mean is greater than requested date
    return empty_values() if p1.nil?
    # reset to 0 hours is needed to avoid period overlapping producing wrong counts; periods are defined in days
    # p1 = p1.change(hour: 0)
    throw :mean_fails if !self.end_time.nil? && self.end_time > p1
    self.end_time = p0 if self.end_time.nil?
    # what if end_time is nil?
    # self.end_time to nil means no data is available, return zeroes
    return empty_values() if self.end_time.nil?
    sv = values()
    return sv if self.end_time == p1
    # in case of period not nil, verify if there are holes in data
    if false && !self.period.nil? && holes_in_data(p0, p1)
      # calculate grouped mean for whole period
      calculate_grouped_mean_for_whole_period(p0, p1, sv)
    else
      # calculate grouped mean incrementally
      calculate_grouped_mean_incrementally(p0, p1, sv)
    end
    # save new starting and ending periods
    update(start_time: p0, end_time: p1)
    sv
  end

  def holes_in_data(p0, p1)
    power = 3600.0 / STAT_TIME()
    r = Pulse.where(node: self.node).where('pulse_time >= ? and pulse_time <= ?', p0, p1).where('power < ?', power).limit(1)
    !r.empty?
  end

  def calculate_grouped_mean_incrementally(p0, p1, sv)
    if self.end_time <= p0
      sv.each do |g, v|
        v.mean = 0.0
        v.sum_weight = 0.0
      end
      self.end_time = p0
    elsif !self.start_time.nil? && self.start_time < p0
      # query from initial interval to be removed
      rv = do_raw_mean_grouped(self.start_time, p0)
      # subtract extracted values from current stat_values
      sv.each do |g, v|
        m1, s1 = rv[g].nil? ? [0.0, 0.0] : [rv[g].sum_val, rv[g].sum_weight]
        # throw :mean_fails if v.sum_weight == 0
        s2 = v.sum_weight - s1
        if v.sum_weight > 0 && s2 > 0
          v.mean = (v.mean * v.sum_weight - m1) / s2
          v.sum_weight = s2
        else
          v.mean, v.sum_weight = 0.0, 0.0
        end
      end
    end
    # query additional data to be added to stat_values
    rv = do_raw_mean_grouped(self.end_time, p1)
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
  end

  def calculate_grouped_mean_for_whole_period(p0, p1, sv)
    rv = do_raw_mean_grouped(p0, p1)
    sv.each do |g, v|
      m, s = rv[g].nil? || rv[g].sum_weight == 0 ? [0.0, 0.0] : [rv[g].sum_val / rv[g].sum_weight, rv[g].sum_weight]
      v.update(mean: m, sum_weight: s)
    end
  end

  def do_raw_mean_grouped(p0, p1)
    res = raw_mean_grouped(p0, p1)
    rv = res.index_by(&:group_by)
    unless self.where_clause.nil?
      res1 = raw_mean_grouped(p0, p1, WHERE_CLAUSE())
      rv1 = res1.index_by(&:group_by)
      # pp rv1
      rv.each {|g, v| v.sum_val = rv1[g].nil? ? 0.0 : rv1[g].sum_val }
    end
    g = TIME_GROUPING(p0)
    unless rv[g].nil?
      # adjust sum_weight for initial interval
      ss_old = rv[g].sum_weight
      rv[g].sum_weight -= DIFF_TIME(p0)
      # pp "--",p0, p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
    end
    g = TIME_GROUPING(p1)
    unless rv[g].nil?
      ss_old = rv[g].sum_weight
      rv[g].sum_weight += DIFF_TIME(p1) - 1.0
      rv[g].sum_val -= 1 if self.where_clause.nil? #|| StatService.WHERE_CLAUSE_EXPR(stat, p1)
      # pp "++", p0,p1, g, ss_old, rv[g].sum_val, rv[g].sum_weight
    end
    rv
  end

# @param [Timestamp] beginning of the period
# @param [Timestamp] ending of the period
# @param [String] where clause to apply
  def raw_mean_grouped(p0, p1, where_clause = nil)
    subq = Pulse.where(node: self.node)
    subq = subq.where(where_clause) unless where_clause.nil?
    subq = subq.group(GROUPING()).select(SELECT()).where('pulse_time >= ? and pulse_time <= ?', p0, p1)
    Pulse.from(subq, :pulses).select(:sum_val, :sum_weight, :group_by)
  end

  def verify_period(end_period)
    # p1 = p1.nil? ? self.where(node: node).maximum(:pulse_time) : convert_date(p1)
    p1 = end_period.nil? ? Time.zone.now : convert_date(end_period)
    return nil, nil if p1.nil?
    mm = Pulse.where(node: self.node)
    unless self.period.nil?
      p_len, p_typ = Stat.to_period(self.period)
      mm = mm.where("pulse_time >= timezone('#{tz}', date_trunc('#{P_TRUNC[p_typ]}', timezone('#{tz}', timezone('UTC', timestamp ?)))) - interval '? #{P_TYPES[p_typ]}'", p1, p_len)
    end
    mm = mm.where('pulse_time <= ?', p1).select('min(pulse_time) as min_t, max(pulse_time) as max_t')
    # min = mm.minimum(:pulse_time)
    # return nil, nil if min.nil?
    return nil, nil if mm[0].min_t.nil? || mm[0].min_t > p1
    # workaround to convert timestamp to correct timezone, as rails fails to do correct conversion with custom fields
    # return [(mm[0].attributes_before_type_cast['min_t']), (mm[0].attributes_before_type_cast['max_t'])]
    return [Time.zone.parse(mm[0].attributes_before_type_cast['min_t'] + ' UTC'), Time.zone.parse(mm[0].attributes_before_type_cast['max_t'] + ' UTC')]
    # return [min, p1]
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

  def values
    sv = stat_values.order(:group_by).index_by(&:group_by)
    for i in 0..(GROUP_SIZE() - 1) do
      sv[i] = stat_values.new(group_by: i) if sv[i].nil?
    end
    sv
  end

  def empty_values
    stat_values.delete_all
    values
  end

  module ClassMethods

    def calc(node, stat, time, period = nil, where_clause = nil, cached = true)
      s = find_or_initialize_by(node: node, stat: stat, period: period, where_clause: where_clause)
      if (cached)
        stat < GROUP_BY_HOUR ? s.mean : s.values()
      else
        s.save
        stat < GROUP_BY_HOUR ? s.calc_mean(time) : s.grouped_mean(time)
      end
    end

    def find_stats_to_update(seconds)
      Stat.where("stats.stat is not null and stats.start_time is not null and stats.end_time is not null and stats.end_time + interval '? seconds' < (select max(p.pulse_time) from pulses p where p.node_id = stats.node_id)", seconds)
    end

    def to_period(num)
      return nil if num.nil?
      p_len = num >> 3
      p_typ = num & 7
      return p_len, p_typ
    end

    def from_period(p_len, p_typ)
      p_len.nil? ? nil : (p_typ & 7) + (p_len << 3)
    end

    def hourly_mean(node, time = nil, period = nil)
      calc(node, HOURLY, time, period, nil, false)
    end

    def daily_mean(node, time = nil, period = nil, where_clause = nil)
      calc(node, DAILY, time, period, where_clause, false)
    end

    def monthly_mean(node, time = nil, period = nil)
      calc(node, MONTHLY, time, period, nil, false)
    end

    def yearly_mean(node, time = nil, period = nil)
      calc(node, YEARLY, time, period, nil, false)
    end

    def weekly_grouped_mean(node, time = nil, period = nil)
      calc(node, GROUP_BY_WDAY, time, period, nil, false)
    end

    def hourly_grouped_mean(node, time = nil, period = nil)
      calc(node, GROUP_BY_HOUR, time, period, nil, false)
    end

    def monthly_grouped_mean(node, time = nil, period = nil)
      calc(node, GROUP_BY_DAY_OF_MONTH, time, period, nil, false)
    end

    def yearly_grouped_mean(node, time = nil, period = nil)
      calc(node, GROUP_BY_MONTH, time, period, nil, false)
    end

    def daily_per_month_grouped_mean(node, time = nil, period = nil, where_clause = nil)
      calc(node, GROUP_BY_DAILY_PER_MONTH, time, period, where_clause, false)
    end

    def daily_slot_per_month_grouped_mean(node, time = nil, period = nil, where_clause = nil)
      calc(node, GROUP_BY_DAILY_PER_MONTH, time, period, where_clause, false)
    end

    def hourly_mean_cached(node, time = nil, period = nil)
      calc(node, HOURLY, time, period, nil, true)
    end

    def daily_mean_cached(node, time = nil, period = nil, where_clause = nil)
      calc(node, DAILY, time, period, where_clause, true)
    end

    def monthly_mean_cached(node, time = nil, period = nil)
      calc(node, MONTHLY, time, period, nil, true)
    end

    def yearly_mean_cached(node, time = nil, period = nil)
      calc(node, YEARLY, time, period, nil, true)
    end

    def weekly_grouped_mean_cached(node, time = nil, period = nil)
      calc(node, GROUP_BY_WDAY, time, period, nil, true)
    end

    def hourly_grouped_mean_cached(node, time = nil, period = nil)
      calc(node, GROUP_BY_HOUR, time, period, nil)
    end

    def monthly_grouped_mean_cached(node, time = nil, period = nil)
      calc(node, GROUP_BY_DAY_OF_MONTH, time, period, nil)
    end

    def yearly_grouped_mean_cached(node, time = nil, period = nil)
      calc(node, GROUP_BY_MONTH, time, period, nil)
    end

    def daily_per_month_grouped_mean_cached(node, time = nil, period = nil, where_clause = nil)
      calc(node, GROUP_BY_DAILY_PER_MONTH, time, period, where_clause, true)
    end

    def daily_slot_per_month_grouped_mean_cached(node, time = nil, period = nil, where_clause = nil)
      calc(node, GROUP_BY_DAILY_PER_MONTH, time, period, where_clause, true)
    end

    def initialize_stats()
      s = Array.new
      Node.where('not exists(select * from stats where stats.node_id = nodes.id)').find_each do |node|
        s << Stat.find_or_create_by(node: node, stat: Stat::HOURLY)
        s << Stat.find_or_create_by(node: node, stat: Stat::HOURLY, period: Stat.from_period(24, Stat::P_HOUR))
        s << Stat.find_or_create_by(node: node, stat: Stat::DAILY)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_HOUR)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_HOUR, period: Stat.from_period(23, Stat::P_HOUR))
        s << Stat.find_or_create_by(node: node, stat: Stat::DAILY, period: Stat.from_period(7, Stat::P_DAY))
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_WDAY)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_WDAY, period: Stat.from_period(6, Stat::P_DAY))
        s << Stat.find_or_create_by(node: node, stat: Stat::DAILY, period: Stat.from_period(1, Stat::P_MONTH))
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_DAY_OF_MONTH)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_DAY_OF_MONTH, period: Stat.from_period(1, Stat::P_DAY_MONTH))
        s << Stat.find_or_create_by(node: node, stat: Stat::MONTHLY)
        s << Stat.find_or_create_by(node: node, stat: Stat::MONTHLY, period: Stat.from_period(12, Stat::P_MONTH))
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_MONTH)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_MONTH, period: Stat.from_period(11, Stat::P_MONTH))
        s << Stat.find_or_create_by(node: node, stat: Stat::DAILY, period: Stat.from_period(1, Stat::P_YEAR), where_clause: :F1)
        s << Stat.find_or_create_by(node: node, stat: Stat::DAILY, period: Stat.from_period(1, Stat::P_YEAR), where_clause: :F2)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_DAILY_PER_MONTH, period: Stat.from_period(11, Stat::P_MONTH), where_clause: :F1)
        s << Stat.find_or_create_by(node: node, stat: Stat::GROUP_BY_DAILY_PER_MONTH, period: Stat.from_period(11, Stat::P_MONTH), where_clause: :F2)
      end
      s
    end

  end

end