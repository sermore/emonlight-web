class Stat < ActiveRecord::Base
  belongs_to :node
  has_many :stat_values, dependent: :delete_all

  def self.current_stat_mean(current_node, stat, period, where_clause = nil)
    Stat.find_or_initialize_by(node: current_node, stat: stat, period: period, where_clause: where_clause.nil? ? 0 : where_clause.hash)
  end

  def values
  	sv = stat_values.order(:group_by).index_by(&:group_by)
    for i in 0..(StatService::GROUP_SIZE[stat - StatService::GROUP_BY_HOUR] - 1) do
    	sv[i] = stat_values.new(group_by: i) if sv[i].nil?
    end
    sv
  end

  def empty_values
  	stat_values.delete_all
  	values
  end

end