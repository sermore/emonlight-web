class StatsController < ApplicationController

  before_action :authenticate_user!, :current_node

  def dashboard
  	@charts = "real_time", "daily", "weekly", "monthly", "yearly"
  end

  def real_time_data
  	time = params[:time] ? Time.parse(params[:time]) : Time.now - 5
  	data = Pulse.where("node_id = :node and pulse_time > :time", { node: params[:node_id], time: time }).order(:pulse_time).pluck(:pulse_time, :power)
  	render json: data
  end

	def yearly_data
		now = params[:d].nil? ? Date.today + 1 : Date.parse(params[:d]) # @now # Date.today

		mean_all, mean_last = Pulse.monthly_mean(current_node), Pulse.monthly_mean(current_node, now << 12, now)
		all, last = Pulse.yearly(current_node), Pulse.yearly(current_node, now << 12, now)

		data = Array.new(5) { Array.new(12, 0) }
		data[0] = Date::MONTHNAMES[1..12]
		all.each { |w| data[1][w[0].to_i - 1] = w[1] }
		last.each { |w| data[2][w[0].to_i - 1] = w[1] }
		data[3] = Array.new(12, mean_all.to_f)
		data[4] = Array.new(12, mean_last.to_f)
		pp data
  	render json: data.transpose
	end

	def monthly_data
		now = params[:d].nil? ? Date.today + 1 : Date.parse(params[:d]) # @now # Date.today

		mean_all, mean_last = Pulse.daily_mean(current_node), Pulse.daily_mean(current_node, now << 1, now)
		all, last = Pulse.monthly(current_node), Pulse.monthly(current_node, now << 1, now)

		data = Array.new(5) { Array.new(31, 0) }
		data[0] = [*1..31]
		all.each { |w| data[1][w[0].to_i - 1] = w[1] }
		last.each { |w| data[2][w[0].to_i - 1] = w[1] }
		data[3] = Array.new(31, mean_all.to_f)
		data[4] = Array.new(31, mean_last.to_f)
		pp data
  	render json: data.transpose
	end

	def weekly_data
		now = params[:d].nil? ? Date.today + 1 : Date.parse(params[:d]) # @now # Date.today

		mean_all, mean_last = Pulse.daily_mean(current_node), Pulse.daily_mean(current_node, now - 7, now)
		all, last = Pulse.weekly(current_node), Pulse.weekly(current_node, now - 7, now)

		pp all
		data = Array.new(5) { Array.new(7, 0) }
		data[0] = Date::DAYNAMES
		all.each { |w| data[1][w[0].to_i] = w[1] }
		last.each { |w| data[2][w[0].to_i] = w[1] }
		data[3] = Array.new(7, mean_all.to_f)
		data[4] = Array.new(7, mean_last.to_f)
		pp data
  	render json: data.transpose
	end

	def daily_data
		now = params[:d].nil? ? Date.today + 1 : Date.parse(params[:d]) # @now # Date.today
		Time.zone = "Europe/Rome"
		mean_all, mean_last = Pulse.hourly_mean(current_node), Pulse.hourly_mean(current_node, now - 1, now)
		all, last = Pulse.daily(current_node), Pulse.daily(current_node, now - 1, now)

		data = Array.new(5) { Array.new(24, 0) }
		data[0] = [*0..23]
		all.each { |w| data[1][w[0].to_i] = w[1] }
		last.each { |w| data[2][w[0].to_i] = w[1] }
		data[3] = Array.new(24, mean_all.to_f)
		data[4] = Array.new(24, mean_last.to_f)
		pp data
  	render json: data.transpose
	end

end
