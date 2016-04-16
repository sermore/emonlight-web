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
		opts = { force: params[:force] == "true", expires_in: 10.minutes }
		q = DataService.cached_calc(:yearly_data, current_node, params, opts)
  	render json: q
	end

	def monthly_data
		opts = { force: params[:force] == "true", expires_in: 10.minutes }
		q = DataService.cached_calc(:monthly_data, current_node, params, opts)
  	render json: q
	end

	def weekly_data
		opts = { force: params[:force] == "true", expires_in: 10.minutes }
		q = DataService.cached_calc(:weekly_data, current_node, params, opts)
  	render json: q
	end

	def daily_data
		opts = { force: params[:force] == "true", expires_in: 5.minutes }
		q = DataService.cached_calc(:daily_data, current_node, params, opts)
  	render json: q
	end

	def time_series_data
		opts = { force: params[:force] == "true", expires_in: 5.minutes }
		q = DataService.cached_time_series_data(current_node, params, opts)
  	render plain: q
	end

	def daily_per_month_data
		opts = { force: params[:force] == "true", expires_in: 10.minutes }
		q = DataService.cached_calc(:daily_per_month_data, current_node, params, opts)
  	render json: q
	end

	def slot_percentage_data
		opts = { force: params[:force] == "true", expires_in: 10.minutes }
		q = DataService.cached_calc(:slot_percentage_data, current_node, params, opts)
  	render json: q
	end

	def time_interval
		p = current_node.pulses.order(:pulse_time).first
		t0 = p.pulse_time if p
		p = current_node.pulses.order(:pulse_time).last
		t1 = p.pulse_time if p
		render json: { time_start: t0, time_end: t1 }
	end

end

