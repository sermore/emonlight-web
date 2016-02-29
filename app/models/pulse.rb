require 'csv'

class Pulse < ActiveRecord::Base
  belongs_to :node
  extend StatService

  # def self._raw_mean(current_node, grouping, start_period = nil, end_period = nil)
  #   subq = self.where(node: current_node).group(GROUPING[grouping]).select("count(*) as mean, #{GROUPING[grouping]} as time_group")
  #   subq = subq.where('pulse_time >= ?', start_period) unless start_period.nil?
  #   subq = subq.where('pulse_time < ?', end_period) unless end_period.nil?
  #   if start_period.nil?
  #     subq = from(subq, :pulses).select("avg(mean) as mean, count(*) as sum_weight")
  #                # .pluck(:mean, :sum_weight)
  #   else
  #     # subq = subq.pluck(:mean, :time_group)
  #   end
  #   # pp subq
  #   subq
  # end


  def self.raw(current_node, start_period, end_period, len = 100, limit = nil, offset = nil)
    # p = (Time.zone.parse(end_period) - Time.zone.parse(start_period)) / len
    #		begin
    start_v = start_period #Time.zone.parse(start_period)
    end_v = end_period #Time.zone.parse(end_period)
    len_v = Integer(len)
# step in seconds between values
    step = (end_v - start_v) / len_v
#		rescue ArgumentError
#		end
    if step > 300
      #.select("min(pulse_time) + (max(pulse_time) - min(pulse_time))/2.0 as pulse_time, count(*) * 3600.0 / #{step} as power")
      where('node_id = :node and pulse_time >= :start_p and pulse_time < :end_p', {node: current_node, start_p: start_v, end_p: end_v})
          .group("trunc(extract(epoch from timezone('#{tz}', pulse_time)) / #{step})")
          .limit(limit)
          .offset(offset)
          .order("trunc(extract(epoch from timezone('#{tz}', pulse_time)) / #{step})")
          .pluck("min(timezone('#{tz}', pulse_time)) + (max(pulse_time) - min(pulse_time))/2.0 as pulse_time, count(*) * 3600.0 / #{step} as power")
      # .map { |r| [ r.pulse_time, r.power ] }
    else
      where(['node_id = :node and pulse_time > :start_p and pulse_time < :end_p', {node: current_node, start_p: start_period, end_p: end_period}])
          .limit(limit)
          .offset(offset)
          .order(:pulse_time)
          .select("timezone('#{tz}', pulse_time) as pulse_time", :pulse_time)
          .pluck("timezone('#{tz}', pulse_time) as pulse_time", :power)
      # .map { |r| [ r.pulse_time, r.power ] }
    end
  end

  # def self._mean(current_node, period, start_period = nil, end_period = nil, where_clause = nil)
  #   t0, t1 = set_period(current_node, start_period, end_period)
  #   dt = t1 - t0
  #   dt = period < dt ? dt / period : 1
  #   # pp t0, t1, dt
  #   Pulse.where(node: current_node)
  #       .where('pulse_time >= :start_p and pulse_time < :end_p', {start_p: t0, end_p: t1})
  #       .where(where_clause)
  #       .count()/dt
  # end


  # def self._mean(current_node, group_clause, start_period = nil, end_period = nil, where_clause = nil)
  #   subq = Pulse.where(node: current_node)
  #              .group(group_clause)
  #              .select('count(*) as power')
  #   subq = subq.where('pulse_time >= :start_p and pulse_time < :end_p', {start_p: start_period, end_p: end_period}) if start_period != nil && end_period != nil
  #   from(subq, :pulses).average(:power)
  # end

  # def self._extract(current_node, group_clause, select_clause, order_clause, start_period = nil, end_period = nil, where_clause = nil)
  #   subq = Pulse.where(node: current_node)
  #              .where(where_clause)
  #              .group(group_clause)
  #              .select(select_clause)
  #              .order(order_clause)
  #   subq = subq.where('pulse_time >= :start_p and pulse_time < :end_p', {start_p: start_period, end_p: end_period}) if start_period != nil && end_period != nil
  #   from(subq, :pulses).pluck(:time_period, :power)
  # end

  # def self.daily_slot_per_month(current_node, slot_clause, start_period = nil, end_period = nil)
  #   t0, t1 = set_period(current_node, start_period, end_period)
  #   days = (t1 - t0)/86400.0
  #   t11 = t1 - 86400
  #   q = Pulse.where(node: current_node)
  #           .where(slot_clause)
  #           .group("extract(year from timezone('#{StatService.tz}', pulse_time))::integer, extract(month from timezone('#{StatService.tz}', pulse_time))::integer")
  #           .order("extract(year from timezone('#{StatService.tz}', pulse_time))::integer, extract(month from timezone('#{StatService.tz}', pulse_time))::integer")
  #           .where('pulse_time >= :start_p and pulse_time < :end_p', {start_p: t0, end_p: t1})
  #           .select("count(pulse_time)/1000.0 as power, extract(month from timezone('#{StatService.tz}', pulse_time))::integer as month, extract(year from timezone('#{StatService.tz}', pulse_time))::integer as year")
  #   # .pluck(:month, :year, :power)
  #   q.each do |r|
  #     s0 = t0.month == r.month && t0.year == r.year ? t0.day : 1
  #     s1 = t11.month == r.month && t11.year == r.year ? t11.day : Time.zone.local(r.year, r.month, 1).end_of_month.day
  #     r.power = r.power / (s1 - s0 + 1)
  #   end
  #   # pp q
  # end

  def self.import_xx(node_id, file, truncate = true)
    t0 = 0
    current_node = Node.find(node_id)
    ActiveRecord::Base.transaction do
      #ActiveRecord::Base.connection.execute('TRUNCATE pulses RESTART IDENTITY') if truncate
      i = 0
      CSV.foreach(file, :headers => false) do |row|
        t1 = row[0].to_f + row[1].to_f / 1.0e9
        # logger.debug "#{++i}: #{Time.zone.at(row[0].to_i, row[1].to_f / 1.0e3).to_s(:db)}"
        begin
          q = Pulse.create!(node: current_node, :pulse_time => Time.zone.at(row[0].to_i + row[1].to_d / 1.0e9), :power => row[2])
        rescue
          logger.error "Error importing row #{i}: #{row}"
          raise
        end
        t0 = t1
        #puts q.pulse_time.iso8601(6)
      end
    end
  end

  def self.import(node_id, file, format, clear_on_import=false)
    current_node = Node.find(node_id)
    read_func, row_read_func = case format
    when 't2'
    	[:read_csv, :read_row_sec_msec]
    when 't1'
    	[:read_csv, :read_row_csv]
    end
    Pulse.read(current_node, file, clear_on_import, read_func, row_read_func)
  end

  def self.export(current_node)
    CSV.generate do |csv|
      # csv << [:pulse_time, :power]
      where(node: current_node).order(:pulse_time).each do |row|
        csv << [row.pulse_time.iso8601(6), row.power]
      end
    end
  end

  private

  def self.to_date(date, default)
    case date
      when nil
        default
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

  def self.set_period(current_node, start_period = nil, end_period = nil)
    s0, s1 = current_node.pulses.order(:pulse_time).first.pulse_time, current_node.pulses.order(:pulse_time).last.pulse_time
    t0, t1 = to_date(start_period, s0), to_date(end_period, s1)
    [t0 < s0 ? s0 : t0, t1 > s1 ? s1 : t1]
  end

  def self.calc_power(pulses_per_kwh, dt)
    return (3600000.0 / dt) / pulses_per_kwh
  end

  def self.calc_last_time(current_node, time)
    Pulse.where("node_id = :node and pulse_time < :time", {node: current_node, time: time}).maximum(:pulse_time)
  end

  def self.read_power(current_node, time, last_time)
    if !time.nil?
      last_time = calc_last_time(current_node, time) if last_time.nil?
      if last_time.nil?
        power = 0
      else
        dt = (time - last_time).to_f
        power = last_time.nil? ? 0.0 : calc_power(current_node.pulses_per_kwh, dt)
        logger.debug "T=#{time}, L=#{last_time}, dt=#{dt}, power=#{power}"
      end
      return last_time, time, power
    end
    return nil, nil, nil
  end

  def self.read_simple(data, &block)
    for row in data do
      block.call(row)
    end
  end

  def self.read_row_simple(row)
    (row.is_a? Array) ? row : [row, nil]
  end

  def self.read_row_csv(row)
    [Time.zone.parse(row[0]), row[1].to_d]
  end

  def self.read_row_sec_msec(row)
    #time_number = row[0].to_f + row[1].to_f / 1.0e9
    #time = Time.zone.at(row[0].to_i, row[1].to_i)
    t = (row.is_a? Array) && row.length > 1 ? row[0].to_i + row[1].to_d / 1.0e9 : 0
    time, power = t == 0 ? [nil, nil] : [Time.zone.at(t), row.length > 2 ? row[2].to_f : nil]
  end

  def self.read_csv(data, &block)
    CSV.foreach(data, :headers => false) { |row| block.call(row) }
  end

  def self.read(current_node, data, clear_on_import, read_func, read_row_func, interval = [])
    # verify that no values are already present in interval being inserted
    if !interval.nil? && !interval.empty? && interval.length == 2 && Pulse.where(node: current_node).where("pulse_time between ? and ?", interval[0], interval[1]).count() > 0
      return 0
    end
    i = 0
    ActiveRecord::Base.transaction do
      last_time = nil
      Pulse.where(node: current_node).delete_all if clear_on_import == true
      Pulse.send(read_func, data) { |r|
        begin
          time_in, power_in = Pulse.send(read_row_func, r)
          last_time, time, power = read_power(current_node, time_in, last_time)
          if !time.nil? && (last_time.nil? || (!last_time.nil? && time > last_time && time - last_time < 1.year))
            q = Pulse.create!(node: current_node, :pulse_time => time, :power => (power == 0 && !power_in.nil? && power_in > 0 ? power_in : power))
            if !power_in.nil? && (power_in - power).abs > 1e-4
              logger.warn "power mismatch at #{time}: expected #{power_in}, calculated #{power}"
            end
            last_time = time
            i += 1
          else
          	logger.error "Discarding row #{i}: #{r}"
          end
        rescue Exception => e
          logger.error "Error reading row #{i}: #{r}"
          raise
        end
      }
    end
    return i
  end

# private_class_method :read_simple, :read_csv, :read_row_simple, :read_row_sec_msec
end
