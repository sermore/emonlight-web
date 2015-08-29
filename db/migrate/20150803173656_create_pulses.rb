class CreatePulses < ActiveRecord::Migration
  def change
    create_table :pulses do |t|
      t.datetime :pulse_time, limit: 6
      t.float :power

      #t.timestamps null: false
    end
  end
end
