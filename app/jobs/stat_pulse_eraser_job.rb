class StatPulseEraserJob < ActiveJob::Base
  queue_as :default

  after_perform do |job|
    StatPulseEraserJob.set(wait: 10.minutes).perform_later
  end

  def perform(*args)
    n = Stat.erasable_pulses.count
    logger.debug "Erase #{n} pulses"
    Stat.erase_pulses
  end
end
