class CreateStats < ActiveRecord::Migration
  def change
    create_table :stats do |t|
      t.references :node, index: true, foreign_key: true
      t.integer :stat
      t.integer :period
      t.decimal :where_clause
      t.float :mean, null: false, default: 0
      t.float :sum_weight, null: false, default: 0
      t.datetime :start_time, limit: 6
      t.datetime :end_time, limit: 6
      # t.timestamps null: false
    end
  end
end
