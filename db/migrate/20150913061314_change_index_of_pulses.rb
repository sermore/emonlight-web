require_relative '20150803173910_add_index_to_pulses'

class ChangeIndexOfPulses < ActiveRecord::Migration
  def change
  	revert AddIndexToPulses
  	add_index :pulses, [ :node_id, :pulse_time ]
  end
end
