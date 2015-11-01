class MakePulsePerKWhNonNullable < ActiveRecord::Migration
  def change
  	change_column :nodes, :pulses_per_kwh, :integer, null: false
  end
end
