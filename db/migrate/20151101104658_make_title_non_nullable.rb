class MakeTitleNonNullable < ActiveRecord::Migration
  def change
  	change_column :nodes, :title, :string, null: false
  end
end
