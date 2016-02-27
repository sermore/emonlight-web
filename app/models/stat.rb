class Stat < ActiveRecord::Base
  belongs_to :node
  has_many :stat_values, dependent: :delete_all

  def self.current_stat_mean(current_node, stat, period)
    Stat.find_or_initialize_by(node: current_node, stat: stat_period(stat, period))
  end

  def self.stat_period(stat, period)
  	period.nil? ? stat : (1 + stat) * 1000 + period
  end

  def values
  	sv = stat_values.order(:group_by).index_by(&:group_by)
    for i in 0..(StatService::GROUP_SIZE[stat_index - StatService::GROUP_BY_HOUR] - 1) do
    	sv[i] = stat_values.new(group_by: i) if sv[i].nil?
    end
    sv
  end

  def empty_values
  	stat_values.delete_all
  	values
  end

  def stat_index
  	s = stat >= 1000 ? (stat / 1000).to_i - 1 : stat
  end

end