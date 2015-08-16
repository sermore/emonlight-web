class AddIndexToPulses < ActiveRecord::Migration
  def change
    add_index :pulses, :pulse_time
  end
end
