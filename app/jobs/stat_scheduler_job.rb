class StatSchedulerJob < ActiveJob::Base
  queue_as :default

  after_perform do |job|
    StatSchedulerJob.set(wait: 10.minutes).perform_later
  end

  def perform(*args)
    # TODO remove dependance between job and Stat id
  Stat.initialize_stats.each do |stat|
      StatUpdaterJob.perform_later(stat)
    end
    Stat.find_stats_to_update(300).find_each do |stat|
      StatUpdaterJob.perform_later(stat)
    end
  end

end
