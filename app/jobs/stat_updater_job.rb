class StatUpdaterJob < ActiveJob::Base
  queue_as :default

  def perform(stat)
    Time.zone = stat.node.time_zone unless stat.node.time_zone.nil?
    Stat.calc(stat.node, stat.stat, Time.zone.now, stat.period, stat.where_clause, false)
  end
end
