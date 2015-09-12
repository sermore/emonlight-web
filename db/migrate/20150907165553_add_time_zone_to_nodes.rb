class AddTimeZoneToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :time_zone, :string
  end
end
