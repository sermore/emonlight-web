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
		q = Rails.cache.fetch("#{current_node.cache_key}/real_time_data", expires_in: 1.seconds) do
			time = params[:time] ? Time.zone.parse(params[:time]) : Time.zone.now - 5
			data = Pulse.where("node_id = :node and pulse_time > :time", { node: params[:node_id], time: time }).order(:pulse_time).pluck(:pulse_time, :power)
		end
		render json: q
	end

	def yearly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/yearly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today + 1 : Time.zone.parse(params[:d])
			t0 = t1 << 12

			mean_all, mean_last = Pulse.monthly_mean(current_node), Pulse.monthly_mean(current_node, t0, t1)
			all, last = Pulse.yearly(current_node), Pulse.yearly(current_node, t0, t1)

			data = Array.new(5) { Array.new(12, 0) }
			data[0] = Date::MONTHNAMES[1..12]
			all.each { |w| data[1][w[0].to_i - 1] = w[1] }
			last.each { |w| data[2][w[0].to_i - 1] = w[1] }
			data[3] = Array.new(12, mean_all.to_f)
			data[4] = Array.new(12, mean_last.to_f)
			{ last_update: Time.zone.now, data: data.transpose }
		end
  	render json: q
	end

	def monthly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/monthly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today + 1 : Time.zone.parse(params[:d])
			t0 = t1 << 1

			mean_all, mean_last = Pulse.daily_mean(current_node), Pulse.daily_mean(current_node, t0, t1)
			all, last = Pulse.monthly(current_node), Pulse.monthly(current_node, t0, t1)

			data = Array.new(5) { Array.new(31, 0) }
			data[0] = [*1..31]
			all.each { |w| data[1][w[0].to_i - 1] = w[1] }
			last.each { |w| data[2][w[0].to_i - 1] = w[1] }
			data[3] = Array.new(31, mean_all.to_f)
			data[4] = Array.new(31, mean_last.to_f)
			{ last_update: Time.zone.now, data: data.transpose }
		end
  	render json: q
	end

	def weekly_data
		opts = { force: params[:force] == "true", expires_in: 1.hours }
		q = Rails.cache.fetch("#{current_node.cache_key}/weekly_data", opts) do
			t1 = params[:d].nil? ? Time.zone.today + 1 : Time.zone.parse(params[:d])
			t0 = t1 - 7

			mean_all, mean_last = Pulse.daily_mean(current_node), Pulse.daily_mean(current_node, t0, t1)
			all, last = Pulse.weekly(current_node), Pulse.weekly(current_node, t0, t1)

			data = Array.new(5) { Array.new(7, 0) }
			data[0] = Date::DAYNAMES
			all.each { |w| data[1][w[0].to_i] = w[1] }
			last.each { |w| data[2][w[0].to_i] = w[1] }
			data[3] = Array.new(7, mean_all.to_f)
			data[4] = Array.new(7, mean_last.to_f)
			{ last_update: Time.zone.now, data: data.transpose }
		end
  	render json: q
	end

	def daily_data
		opts = { force: params[:force] == "true", expires_in: 15.minutes }
		q = Rails.cache.fetch("#{current_node.cache_key}/daily_data", opts) do
			t1 = params[:d].nil? ? Time.zone.now + 1 : Time.zone.parse(params[:d])
			t0 = t1 - 86400
			mean_all, mean_last = Pulse.hourly_mean(current_node), Pulse.hourly_mean(current_node, t0 , t1)
			all, last = Pulse.daily(current_node), Pulse.daily(current_node, t0, t1)

			data = Array.new(5) { Array.new(24, 0) }
			data[0] = [*0..23]
			all.each { |w| data[1][w[0].to_i] = w[1] }
			last.each { |w| data[2][w[0].to_i] = w[1] }
			data[3] = Array.new(24, mean_all.to_f)
			data[4] = Array.new(24, mean_last.to_f)
			{ last_update: Time.zone.now, data: data.transpose }
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
				end
			end
		end
	end

end

