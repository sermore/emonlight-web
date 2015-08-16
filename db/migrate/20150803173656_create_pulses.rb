class CreatePulses < ActiveRecord::Migration
  def change
    create_table :pulses do |t|
      t.datetime :pulse_time, limit: 6
      t.float :time_interval
      t.float :power
      t.float :elapsed_kwh
      t.integer :pulse_count
      t.integer :raw_count

      #t.timestamps null: false
    end
  end
end
