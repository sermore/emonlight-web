class DataService

  def self.to_data_table(columns, rows)
    Jbuilder.encode do |json|
      json.cols columns
      json.rows rows do |row|
        json.c row do |val|
          json.v (val.is_a?(Time) ? "Date(#{val.year},#{val.month - 1},#{val.day},#{val.hour},#{val.min},#{val.sec},#{(val.usec/1000).to_i})" : val)
          json.f "%.2f" % val if val.is_a?(Numeric) && !val.integer?
        end
      end
    end
  end

  def self.cached_time_series_data(current_node, params, fetch_opts)
    t1 = params[:end_p].nil? ? current_node.pulses.last.pulse_time : Time.zone.parse(params[:end_p])
    t0 = params[:start_p].nil? ? current_node.pulses.first.pulse_time : Time.zone.parse(params[:start_p])
    q = Rails.cache.fetch("#{current_node.cache_key}/raw_data/#{t0}/#{t1}", fetch_opts) do
      rows = Pulse.raw(current_node, t0, t1, 400)
      columns = [ {id: 'time', label: 'Time', type: 'datetime'}, {id: 'power', label: 'Power', type: 'number'} ]
      DataService.to_data_table(columns, rows)
    end
  end

  def self.cached_calc(action, current_node, params, fetch_opts)
    Rails.cache.fetch("#{current_node.cache_key}/#{action}", fetch_opts) do
      new(current_node, params).send(action)
    end
  end

  def initialize(current_node, params)
    @current_node = current_node
    @params = params
  end

  def daily_data
    t1 = @params[:d].nil? ? Time.zone.now + 1 : Time.zone.parse(@params[:d])
    Rails.logger.debug "T=#{t1}"
    # t0 = t1 - 86400

    columns = [{id: 'hour', label: 'Hour', type: 'string'},
               {id: 'power_overall', label: 'Overall', type: 'number'},
               {id: 'power_last', label: 'Last Day', type: 'number'},
               {id: 'mean_overall', label: 'Overall Mean', type: 'number'},
               {id: 'mean_last', label: 'Last Day Mean', type: 'number'},
    ]

    mean_all, mean_last = Stat.hourly_mean_cached(@current_node), Stat.hourly_mean_cached(@current_node, t1, Stat.from_period(24, Stat::P_HOUR))
    all, last = Stat.hourly_grouped_mean_cached(@current_node), Stat.hourly_grouped_mean_cached(@current_node, t1, Stat.from_period(23, Stat::P_HOUR))
    t = Time.zone.now
    data = Array.new(5) { Array.new(24, 0) }
    (0 .. 23).each do |i|
      t += 3600
      h = t.hour
      data[0][i] = h
      data[1][i] = all[h].mean
      data[2][i] = last[h].mean
      data[3][i] = mean_all
      data[4][i] = mean_last
    end
    q = Stat.where(node: @current_node, stat: Stat::GROUP_BY_HOUR).first
    t = q.nil? ? nil : q.end_time
    data.shift while !data[0][1] && !data[0][2]
    {last_update: t, data: DataService.to_data_table(columns, data.transpose)}
  end

  def weekly_data
    t1 = @params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(@params[:d])
    t0 = t1 - 7.day

    columns = [{id: 'day_week', label: 'Day of the Week', type: 'string'},
               {id: 'power_overall', label: 'Overall', type: 'number'},
               {id: 'power_last', label: 'Last 7 days', type: 'number'},
               {id: 'mean_overall', label: 'Overall Mean', type: 'number'},
               {id: 'mean_last', label: 'Last 7 days Mean', type: 'number'},
    ]

    mean_all, mean_last = Stat.daily_mean_cached(@current_node)/1000.0, Stat.daily_mean_cached(@current_node, t1, Stat.from_period(7, Stat::P_DAY))/1000.0
    all, last = Stat.weekly_grouped_mean_cached(@current_node), Stat.weekly_grouped_mean_cached(@current_node, t1, Stat.from_period(6, Stat::P_DAY))

    now = Time.zone.today
    data = Array.new(5) { Array.new(7, 0) }
    ((now-6) .. now).each.with_index do |d, i|
      dd = d.wday
      data[0][i] = Date::DAYNAMES[dd]
      data[1][i] = all[dd].mean/1000.0
      data[2][i] = last[dd].mean/1000.0
      data[3][i] = mean_all
      data[4][i] = mean_last
    end
    q = Stat.where(node: @current_node, stat: Stat::GROUP_BY_WDAY).first
    t = q.nil? ? nil : q.end_time
    data.shift while !data[0][1] && !data[0][2]
    {last_update: t, data: DataService.to_data_table(columns, data.transpose)}
  end

  def monthly_data
    t1 = @params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(@params[:d])
    # t0 = t1 - 1.month

    columns = [{id: 'day_month', label: 'Day', type: 'string'},
               {id: 'power_overall', label: 'Overall', type: 'number'},
               {id: 'power_last', label: 'Last Month', type: 'number'},
               {id: 'mean_overall', label: 'Overall Mean', type: 'number'},
               {id: 'mean_last', label: 'Last Month Mean', type: 'number'},
    ]
    mean_all, mean_last = Stat.daily_mean_cached(@current_node)/1000.0, Stat.daily_mean_cached(@current_node, t1, Stat.from_period(1, Stat::P_MONTH))/1000.0
    all, last = Stat.monthly_grouped_mean_cached(@current_node), Stat.monthly_grouped_mean_cached(@current_node, t1, Stat.from_period(1, Stat::P_DAY_MONTH))
    data = Array.new(5) { Array.new(31, 0) }
    d = (t1.day - 2) % 31
    (0..30).each do |i|
      d = (d + 1) % 31
      data[0][i] = d + 1
      data[1][i] = all[d].mean/1000.0
      data[2][i] = last[d].mean/1000.0
      data[3][i] = mean_all
      data[4][i] = mean_last
    end
    q = Stat.where(node: @current_node, stat: Stat::GROUP_BY_DAY_OF_MONTH, period: nil).first
    t = q.nil? ? nil : q.end_time
    data = data.transpose
    data.slice!(0) while data[0] && data[0][1] == 0 && data[0][2] == 0
    {last_update: t, data: DataService.to_data_table(columns, data)}
  end

  def yearly_data
    t1 = @params[:d].nil? ? (Time.zone.today.in_time_zone + 1.day) : Time.zone.parse(@params[:d])
    # t0 = t1 - 12.month
    columns = [
        {id: 'month', label: 'Month', type: 'string'},
        {id: 'power_overall', label: 'Overall', type: 'number'},
        {id: 'power_last', label: 'Last Year', type: 'number'},
        {id: 'mean_overall', label: 'Overall Mean', type: 'number'},
        {id: 'mean_last', label: 'Last Year Mean', type: 'number'},
    ]
    mean_all, mean_last = Stat.monthly_mean_cached(@current_node)/1000.0, Stat.monthly_mean_cached(@current_node, t1, Stat.from_period(12, Stat::P_MONTH))/1000.0
    all, last = Stat.yearly_grouped_mean_cached(@current_node), Stat.yearly_grouped_mean_cached(@current_node, t1, Stat.from_period(11, Stat::P_MONTH))
    data = Array.new(5) { Array.new(12, 0) }
    m = (t1.month - 1) % 12
    (0 .. 11).each do |i|
      m = (m + 1) % 12
      data[0][i] = Date::MONTHNAMES[m+1]
      data[1][i] = all[m].mean/1000.0
      data[2][i] = last[m].mean/1000.0
      data[3][i] = mean_all
      data[4][i] = mean_last
    end
    q = Stat.where(node: @current_node, stat: Stat::GROUP_BY_MONTH, period: nil).first
    t = q.nil? ? nil : q.end_time
    data = data.transpose
    # data.slice!(0) while data[0][1] == 0 && data[0][2] == 0
    {last_update: t, data: DataService.to_data_table(columns, data)}
  end

  def daily_per_month_data
    t1 = @params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(@params[:d])
    # t0 = t1 - 12.month
    columns = [{id: 'month', label: 'Month', type: 'string'},
               {id: 'f1', label: 'F1', type: 'number'},
               {id: 'f2', label: 'F2', type: 'number'},
               {id: 'sum', label: 'Total', type: 'number', role: 'annotation'},
               {id: 'mean_f1', label: 'F1 Mean', type: 'number'},
               {id: 'mean_f2', label: 'F2 Mean', type: 'number'},
               {id: 'mean_total', label: 'Total Mean', type: 'number'}
    ]
    mp = Stat.from_period(1, Stat::P_YEAR)
    gp = Stat.from_period(11, Stat::P_MONTH)
    mean = Stat.daily_mean_cached(@current_node)/1000.0
    mean_f1 = Stat.daily_mean_cached(@current_node, t1, mp, :F1)/1000.0
    mean_f2 = Stat.daily_mean_cached(@current_node, t1, mp, :F2)/1000.0
    f1 = Stat.daily_slot_per_month_grouped_mean_cached(@current_node, t1, gp, :F1)
    f2 = Stat.daily_slot_per_month_grouped_mean_cached(@current_node, t1, gp, :F2)
    # pp "MEAN=", mean, mean_f1, mean_f2
    data = Array.new(7) { Array.new(12, 0) }
    m = (t1.month - 1) % 12
    (0 .. 11).each do |i|
      m = (m + 1) % 12
      data[0][i] = Date::MONTHNAMES[m+1]
      data[1][i] = f1[m].mean/1000.0
      data[2][i] = f2[m].mean/1000.0
      data[3][i] = data[1][i] + data[2][i]
      data[4][i] = mean_f1
      data[5][i] = mean_f2
      data[6][i] = mean
    end
    q = Stat.where(node: @current_node, stat: Stat::GROUP_BY_DAILY_PER_MONTH, period: gp, where_clause: :F1).first
    t = q.nil? ? nil : q.end_time
    data = data.transpose
    # data.slice!(0) while data[0][1] == 0 && data[0][2] == 0
    {last_update: t, data: DataService.to_data_table(columns, data)}
  end

  def slot_percentage_data
    t1 = @params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(@params[:d])
    # t0 = t1 - 12.month

    columns = [{id: 'slot_names', label: 'Slots', type: 'string'},
               {id: 'slot', label: '%', type: 'number'},
               {id: 'sum', label: 'Total', type: 'number', role: 'annotation'}
    ]

    # mean = Stat.daily_mean(current_node)/1000.0
    p = Stat.from_period(1, Stat::P_YEAR)
    mean_f1 = Stat.daily_mean_cached(@current_node, t1, p, :F1)/1000.0
    mean_f2 = Stat.daily_mean_cached(@current_node, t1, p, :F2)/1000.0
    # pp "MEAN=", mean, mean_f1, mean_f2
    q = Stat.where(node: @current_node, stat: Stat::DAILY, period: p, where_clause: :F1).first
    t = q.nil? ? nil : q.end_time
    data = [["F1", mean_f1, mean_f1 + mean_f2], ["F2", mean_f2, mean_f1 + mean_f2]]
    {last_update: t, data: DataService.to_data_table(columns, data)}
  end

end