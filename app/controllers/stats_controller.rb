class StatsController < ApplicationController

  before_action :authenticate_user!, :verify_current_node

  def dashboard
  	@charts = current_node.dashboard
  	render "chart"
  end

  def chart
  	@charts = [params[:chart]]
  end

	def real_time_data
		time = params[:time] ? Time.zone.parse(params[:time]) : Time.zone.now - 5
		q = Rails.cache.fetch("#{current_node.cache_key}/real_time_data/#{time}", expires_in: 4.seconds) do
			data = Pulse.where("node_id = :node and pulse_time > :time", { node: params[:node_id], time: time }).order(:pulse_time).pluck(:pulse_time, :power)
		end
		render json: q
	end

	def yearly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/yearly_data", opts) do
			t1 = params[:d].nil? ? (Time.zone.today.in_time_zone + 1.day) : Time.zone.parse(params[:d])
			# t0 = t1 - 12.month

			columns = [
				{id: 'month', label: 'Month', type: 'string'}, 
				{id: 'power_overall', label: 'Overall', type: 'number'},
				{id: 'power_last', label: 'Last Year', type: 'number'},
				{id: 'mean_overall', label: 'Overall Mean', type: 'number'},
				{id: 'mean_last', label: 'Last Year Mean', type: 'number'},
			]

			mean_all, mean_last = Pulse.monthly_mean(current_node)/1000.0, Pulse.monthly_mean(current_node, t1, 365)/1000.0
			all, last = Pulse.yearly(current_node), Pulse.yearly(current_node, t1, 365)
			data = Array.new(5) { Array.new(12, 0) }
			m = (t1.month - 1) % 12
			(0 .. 11).each do |i|
				m = (m + 1) % 12
				data[0][i] = Date::MONTHNAMES[m+1]
				data[1][i] = all[m].mean
				data[2][i] = last[m].mean
				data[3][i] = mean_all
				data[4][i] = mean_last
			end
			data = data.transpose
			# data.slice!(0) while data[0][1] == 0 && data[0][2] == 0
			{ last_update: Time.zone.now, data: to_data_table(columns, data) }
		end
  	render json: q
	end

	def monthly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/monthly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(params[:d])
			# t0 = t1 - 1.month

			columns = [ {id: 'day_month', label: 'Day', type: 'string'}, 
				{id: 'power_overall', label: 'Overall', type: 'number'},
				{id: 'power_last', label: 'Last Month', type: 'number'},
				{id: 'mean_overall', label: 'Overall Mean', type: 'number'},
				{id: 'mean_last', label: 'Last Month Mean', type: 'number'},
			]
			mean_all, mean_last = Pulse.daily_mean(current_node)/1000.0, Pulse.daily_mean(current_node, t1, 31)/1000.0
			all, last = Pulse.monthly(current_node), Pulse.monthly(current_node, t1, 31)
			data = Array.new(5) { Array.new(31, 0) }
			d = (t1.day - 2) % 31
			(0..30).each do |i|
				d = (d + 1) % 31
				data[0][i] = d + 1
				data[1][i] = all[d].mean
				data[2][i] = last[d].mean
				data[3][i] = mean_all
				data[4][i] = mean_last
			end
			data = data.transpose
			data.slice!(0) while data[0] && data[0][1] == 0 && data[0][2] == 0
			{ last_update: Time.zone.now, data: to_data_table(columns, data) }
		end
  	render json: q
	end

	def weekly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/weekly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(params[:d])
			t0 = t1 - 7.day

			columns = [ {id: 'day_week', label: 'Day of the Week', type: 'string'}, 
				{id: 'power_overall', label: 'Overall', type: 'number'},
				{id: 'power_last', label: 'Last 7 days', type: 'number'},
				{id: 'mean_overall', label: 'Overall Mean', type: 'number'},
				{id: 'mean_last', label: 'Last 7 days Mean', type: 'number'},
			]

			mean_all, mean_last = Pulse.daily_mean(current_node)/1000.0, Pulse.daily_mean(current_node, t1, 7)/1000.0
			all, last = Pulse.weekly(current_node), Pulse.weekly(current_node, t1, 7)

			now = Time.zone.today
			data = Array.new(5) { Array.new(7, 0) }
			((now-6) .. now).each.with_index do |d, i|
				dd = d.wday
				data[0][i] = Date::DAYNAMES[dd]
				data[1][i] = all[dd].mean
				data[2][i] = last[dd].mean
				data[3][i] = mean_all
				data[4][i] = mean_last
			end
			data.shift while !data[0][1] && !data[0][2]
			{ last_update: Time.zone.now, data: to_data_table(columns, data.transpose) }
		end
  	render json: q
	end

	def daily_data
		opts = { force: params[:force] == "true", expires_in: 15.minutes }
		q = Rails.cache.fetch("#{current_node.cache_key}/daily_data", opts) do
			t1 = params[:d].nil? ? Time.zone.now + 1 : Time.zone.parse(params[:d])
			# t0 = t1 - 86400

			columns = [ {id: 'hour', label: 'Hour', type: 'string'}, 
				{id: 'power_overall', label: 'Overall', type: 'number'},
				{id: 'power_last', label: 'Last Day', type: 'number'},
				{id: 'mean_overall', label: 'Overall Mean', type: 'number'},
				{id: 'mean_last', label: 'Last Day Mean', type: 'number'},
			]

			mean_all, mean_last = Pulse.hourly_mean(current_node), Pulse.hourly_mean(current_node, t1, 1)
			all, last = Pulse.daily(current_node), Pulse.daily(current_node, t1, 1)
			t = Time.zone.now - 86400
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
			data.shift while !data[0][1] && !data[0][2]
			{ last_update: Time.zone.now, data: to_data_table(columns, data.transpose) }
		end
  	render json: q
	end

	def time_series_data
		t1 = params[:end_p].nil? ? current_node.pulses.last.pulse_time : Time.zone.parse(params[:end_p])
		t0 = params[:start_p].nil? ? current_node.pulses.first.pulse_time : Time.zone.parse(params[:start_p])
		opts = { force: params[:force] == "true", expires_in: 15.minutes }
		q = Rails.cache.fetch("#{current_node.cache_key}/raw_data/#{t0}/#{t1}", opts) do
			rows = Pulse.raw(current_node, t0, t1, 400)
			columns = [ {id: 'time', label: 'Time', type: 'datetime'}, {id: 'power', label: 'Power', type: 'number'} ]
			to_data_table(columns, rows)
		end
  	render plain: q
	end

	def daily_per_month_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/daily_per_monthly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(params[:d])
			# t0 = t1 - 12.month

			columns = [ {id: 'month', label: 'Month', type: 'string'}, 
				{id: 'f1', label: 'F1', type: 'number'},
				{id: 'f2', label: 'F2', type: 'number'},
				{id: 'sum', label: 'Total', type: 'number', role: 'annotation'},
				{id: 'mean_f1', label: 'F1 Mean', type: 'number'},
				{id: 'mean_f2', label: 'F2 Mean', type: 'number'},
				{id: 'mean_total', label: 'Total Mean', type: 'number'}
			]

			q_f1 = StatService.WHERE_CLAUSE(:f1)
			q_f2 = StatService.WHERE_CLAUSE(:f2)
			mean = Pulse.daily_mean(current_node)/1000.0
			mean_f1 = Pulse.daily_mean(current_node, t1, 365, q_f1)/1000.0
			mean_f2 = Pulse.daily_mean(current_node, t1, 365, q_f2)/1000.0
			f1 = Pulse.daily_slot_per_month(current_node, t1, 365, q_f1)
			f2 = Pulse.daily_slot_per_month(current_node, t1, 365, q_f2)
			# pp "MEAN=", mean, mean_f1, mean_f2

			data = Array.new(7) { Array.new(12, 0) }
			m = (t1.month - 1) % 12
			(0 .. 11).each do |i|
				m = (m + 1) % 12
				data[0][i] = Date::MONTHNAMES[m+1]
				data[1][i] = f1[m].mean/1000
				data[2][i] = f2[m].mean/1000
				data[3][i] = data[1][i] + data[2][i]
				data[4][i] = mean_f1
				data[5][i] = mean_f2
				data[6][i] = mean
			end
			data = data.transpose
			# data.slice!(0) while data[0][1] == 0 && data[0][2] == 0
			{ last_update: Time.zone.now, data: to_data_table(columns, data) }
		end
  	render json: q
	end

	def slot_percentage_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/slot_percentage_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today.in_time_zone + 1.day : Time.zone.parse(params[:d])
			# t0 = t1 - 12.month

			columns = [ {id: 'slot_names', label: 'Slots', type: 'string'},
				{id: 'slot', label: '%', type: 'number'},
				{id: 'sum', label: 'Total', type: 'number', role: 'annotation'}
			]

			q_f1 = StatService.WHERE_CLAUSE(:f1)
			q_f2 = StatService.WHERE_CLAUSE(:f2)
			# mean = Pulse.daily_mean(current_node)/1000.0
			mean_f1 = Pulse.daily_mean(current_node, t1, 365, q_f1)/1000.0
			mean_f2 = Pulse.daily_mean(current_node, t1, 365, q_f2)/1000.0
			# pp "MEAN=", mean, mean_f1, mean_f2
			data = [ ["F1", mean_f1, mean_f1 + mean_f2], ["F2", mean_f2, mean_f1 + mean_f2] ]
			{ last_update: Time.zone.now, data: to_data_table(columns, data) }
		end
  	render json: q
	end

	def time_interval
		p = current_node.pulses.order(:pulse_time).first
		t0 = p.pulse_time if p
		p = current_node.pulses.order(:pulse_time).last
		t1 = p.pulse_time if p
		render json: { time_start: t0, time_end: t1 }
	end

private

	def to_data_table(columns, rows)
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

end

