class AddDashboardToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :dashboard, :string
  end
end
