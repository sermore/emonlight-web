class Stat < ActiveRecord::Base
  belongs_to :node
  has_many :stat_values, dependent: :delete_all
  include MeanCalculator

  # def self.current_stat_mean(current_node, stat, period, where_clause = nil)
  #   Stat.find_or_initialize_by(node: current_node, stat: stat, period: period, where_clause: where_clause)
  # end

end