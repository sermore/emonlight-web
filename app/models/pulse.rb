require 'csv'

class Pulse < ActiveRecord::Base

	belongs_to :node, dependent: :destroy

	def self.raw(current_node, start_period, end_period, len = 100, limit = nil, offset = nil)
		#p = (Date.parse(end_period) - Date.parse(start_period)) / len
#		begin
		start_v = DateTime.parse(start_period)
		end_v = DateTime.parse(end_period)
		len_v = Integer(len)
		# step in seconds between values
		step = (end_v - start_v) * 86400 / len_v		
#		rescue ArgumentError
#		end
		if step > 300
			where(['node_id = :node and pulse_time between :start_p and :end_p', { node: current_node, start_p: start_period, end_p: end_period } ])
			.group("trunc(extract(epoch from pulse_time) / #{step})")
			.limit(limit)
			.offset(offset)
			.select("min(pulse_time) + (max(pulse_time) - min(pulse_time))/2.0 as pulse_time, count(*) * 3600.0 / #{step} as power")
			.order("trunc(extract(epoch from pulse_time) / #{step})")
			.map { |r| [ r.pulse_time, r.power ] }
		else
			where(['node_id = :node and pulse_time between :start_p and :end_p', { node: current_node, start_p: start_period, end_p: end_period } ])
			.limit(limit)
			.offset(offset)
			.select(:power, :pulse_time)
			.order(:pulse_time)
			.map { |r| [ r.pulse_time, r.power ] }
		end
	end

	def self._mean(current_node, group_clause, start_period = nil, end_period = nil)
		subq = Pulse.where(node: current_node)
			.group(group_clause)
			.select('count(*) as power')
		subq = subq.where('pulse_time >= :start_p and pulse_time < :end_p', { start_p: start_period, end_p: end_period }) if start_period != nil && end_period != nil
		from(subq, :pulses).average(:power)

		# find_by_sql([
		# 	"SELECT AVG(daily_power) AS power FROM (" +
		# 	"	SELECT COUNT(pulse_time) AS daily_power " +
		# 	"	FROM pulses r " +
		# 	"	WHERE node_id = :node " +
		# 	(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
		# 	"	GROUP BY trunc(extract(epoch from pulse_time) / 86400.0) " +
		# 	"	) AS power_daily",
		# 	{ node: current_node, start_p: start_period, end_p: end_period }
		# 	]).first.power
	end

	def self.daily_mean(current_node, start_period = nil, end_period = nil)
		_mean(current_node, "trunc(extract(epoch from pulse_time) / 86400.0)", start_period, end_period)
	end


	def self.hourly_mean(current_node, start_period = nil, end_period = nil)
		_mean(current_node, "trunc(extract(epoch from pulse_time) / 3600.0)", start_period, end_period)
=begin
		find_by_sql([
			"SELECT AVG(hourly_power) AS power FROM (" +
			"	SELECT COUNT(pulse_time) AS hourly_power " +
			"	FROM pulses r " +
			"	WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"	GROUP BY trunc(extract(epoch from pulse_time) / 3600) " +
			"	) AS power_hourly",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).first.power
=end
	end

	def self.monthly_mean(current_node, start_period = nil, end_period = nil)
		_mean(current_node, "extract(year from pulse_time) * 12 + extract(month from pulse_time)", start_period, end_period)
=begin
		find_by_sql([
			"SELECT AVG(monthly_power) AS power FROM (" +
			"	SELECT COUNT(pulse_time) AS monthly_power " +
			"	FROM pulses r " +
			"	WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"	GROUP BY extract(year from pulse_time) * 12 + extract(month from pulse_time) " +
			"	) AS power_monthly",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).first.power
=end
	end

	def self.yearly_mean(current_node, start_period = nil, end_period = nil)
		_mean(current_node, "extract(year from pulse_time)", start_period, end_period)		
=begin
		find_by_sql([
			"SELECT AVG(monthly_power) AS power FROM (" +
			"	SELECT COUNT(pulse_time) AS monthly_power " +
			"	FROM pulses r " +
			"	WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"	GROUP BY extract(year from pulse_time) * 12 + extract(month from pulse_time) " +
			"	) AS power_monthly",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).first.power
=end
	end

	def self._extract(current_node, group_clause, select_clause, order_clause, start_period = nil, end_period = nil)
		subq = Pulse.where(node: current_node)
			.group(group_clause)
			.select(select_clause)
			.order(order_clause)
		subq = subq.where('pulse_time >= :start_p and pulse_time < :end_p', { start_p: start_period, end_p: end_period }) if start_period != nil && end_period != nil
		from(subq, :pulses).pluck(:time_period, :power)
	end

	def self.weekly(current_node, start_period = nil, end_period = nil)
		_extract(current_node, 
			"extract(dow from pulse_time), to_char(pulse_time, 'Day')",
			"(0.0 + count(pulse_time)) / count(distinct(trunc(extract(epoch from pulse_time)/86400.0))) as power, to_char(pulse_time, 'Day') as time_period",
			"extract(dow from pulse_time)",
			start_period, end_period
			)
=begin
		subq = Pulse.where(node: current_node)
			.group("extract(dow from pulse_time), to_char(pulse_time, 'Day')")
			.select("(0.0 + count(pulse_time)) / count(distinct(trunc(extract(epoch from pulse_time)/86400.0))) as power, to_char(pulse_time, 'Day') as week_day")
			.order("extract(dow from pulse_time)")
		subq = subq.where('pulse_time >= :start_p and pulse_time < :end_p', { start_p: start_period, end_p: end_period }) if start_period != nil && end_period != nil
		from(subq, :pulses).pluck(:week_day, :power)
=end
=begin
		find_by_sql([
			"SELECT " +
			"week_day, " +
			"pulse_cnt/ " +
			"(select count(distinct(trunc(extract(epoch from r1.pulse_time)/86400))) " +
			"	from pulses r1 " +
			"	where extract(dow from r1.pulse_time) = week_day_n " +
			"	and node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r1.pulse_time BETWEEN :start_p AND :end_p " : "") +
			") as power " +
			"FROM " +
			"(select " +
			"	extract(dow from r.pulse_time) as week_day_n, " +
			"	to_char(pulse_time, 'Day') as week_day,	" +
			"	count(r.pulse_time) as pulse_cnt " +
			"from pulses r " +
			"WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"GROUP BY extract(dow from r.pulse_time), to_char(r.pulse_time, 'Day') " +
			") as rr " +
			"ORDER BY week_day_n",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).map { |r| [ r.week_day, r.power ] }
=end
	end

	def self.daily(current_node, start_period = nil, end_period = nil)
		_extract(current_node, 
			"extract(hour from pulse_time)",
			"(0.0 + count(pulse_time)) / count(distinct(trunc(extract(epoch from pulse_time)/86400.0))) as power, extract(hour from pulse_time) as time_period",
			"extract(hour from pulse_time)",
			start_period, end_period
			)
=begin
		find_by_sql([
			"SELECT " +
			"hour, " +
			"pulse_cnt/ " +
			"(select count(distinct(trunc(extract(epoch from r1.pulse_time)/86400))) " +
			"	from pulses r1 " +
			"	where extract(hour from r1.pulse_time) = hour " +
			"	and node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r1.pulse_time BETWEEN :start_p AND :end_p " : "") +
			") as power " +
			"FROM " +
			"(select " +
			"	extract(hour from r.pulse_time) as hour, " +
			"	count(r.pulse_time) as pulse_cnt " +
			"from pulses r " +
			(start_period != nil || end_period != nil ? "WHERE r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"GROUP BY extract(hour from r.pulse_time) " +
			") as rr " +
			"ORDER BY hour", 
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).map { |r| [r.hour, r.power] }
=end
	end

	def self.monthly(current_node, start_period = nil, end_period = nil)
		_extract(current_node, 
			"extract(day from pulse_time)",
			"(0.0 + count(pulse_time)) / count(distinct(trunc(extract(epoch from pulse_time)/86400.0))) as power, extract(day from pulse_time) as time_period",
			"extract(day from pulse_time)",
			start_period, end_period
			)
=begin
		find_by_sql([
			"SELECT " +
			"month_day, " +
			"pulse_cnt/ " +
			"(select count(distinct(trunc(extract(epoch from r1.pulse_time)/86400))) " +
			"	from pulses r1 " +
			"	where extract(day from r1.pulse_time) = month_day " +
			"	and node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r1.pulse_time BETWEEN :start_p AND :end_p " : "") +
			") as power " +
			"FROM " +
			"(select " +
			"	extract(day from pulse_time) as month_day, " +
			"	count(r.pulse_time) as pulse_cnt " +
			"from pulses r " +
			"WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"GROUP BY extract(day from pulse_time) " +
			") as rr " +
			"ORDER BY month_day",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).map { |r| [ r.month_day, r.power ] }
=end
	end

	def self.yearly(current_node, start_period = nil, end_period = nil)
		_extract(current_node, 
			"extract(month from pulse_time), to_char(pulse_time, 'Month')",
			"(0.0 + count(pulse_time)) / count(distinct(extract(year from pulse_time) * 12 + extract(month from pulse_time))) as power, to_char(pulse_time, 'Month') as time_period",
			"extract(month from pulse_time)",
			start_period, end_period
			)
=begin
		find_by_sql([
			"SELECT " +
			"month_name, " +
			"pulse_cnt/ " +
			"(select count(distinct(extract(year from r1.pulse_time) * 12 + extract(month from r1.pulse_time))) " +
			"	from pulses r1 " +
			"	where extract(month from r1.pulse_time) = month " +
			"	and node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r1.pulse_time BETWEEN :start_p AND :end_p " : "") +
			") as power " +
			"FROM " +
			"(select " +
			"	extract(month from pulse_time) as month, " +
			"	to_char(pulse_time, 'Month') as month_name,	" +
			"	count(r.pulse_time) as pulse_cnt " +
			"from pulses r " +
			"WHERE node_id = :node " +
			(start_period != nil || end_period != nil ? "AND r.pulse_time BETWEEN :start_p AND :end_p " : "") +
			"GROUP BY extract(month from pulse_time), to_char(r.pulse_time, 'Month') " +
			"ORDER BY month " +
			") as rr ",
			{ node: current_node, start_p: start_period, end_p: end_period }
			]).map { |r| [ r.month_name, r.power ] }
=end
	end

	def self.import(node_id, file, truncate = true)
		t0 = 0
		current_node = Node.find(node_id)
		ActiveRecord::Base.transaction do
			ActiveRecord::Base.connection.execute('TRUNCATE pulses RESTART IDENTITY') if truncate
			i = 0
			CSV.foreach(file, :headers => false) do |row|
				t1 = row[0].to_f + row[1].to_f / 1.0e9
#				logger.debug "#{++i}: #{Time.at(row[0].to_i, row[1].to_f / 1.0e3).to_s(:db)}"
	#			q = Pulse.create!(:pulse_time => Time.at(row[0].to_i, (row[1].to_f / 1.0e3).round), :time_interval => t1 - t0,  :power => row[2], :elapsed_kwh => row[3], :pulse_count => row[4], :raw_count => row[5])
				begin
	 	 			q = Pulse.create!(node: current_node, :pulse_time => Time.at(row[0].to_i, row[1].to_f / 1.0e3), :time_interval => t1 - t0,  :power => row[2], :elapsed_kwh => row[3], :pulse_count => row[4], :raw_count => row[5])
	 	 		rescue
	 	 			logger.error  "Error importing row #{i}: #{row}"
	 	 		end
	  			t0 = t1
	  			#puts q.pulse_time.iso8601(6)
			end
		end
	end

end
