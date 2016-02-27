class CreateStatValues < ActiveRecord::Migration
  def change
    create_table :stat_values do |t|
      t.references :stat, index: true, foreign_key: true
      t.integer :group_by
      t.float :mean, null: false, default: 0
      t.float :sum_weight, null: false, default: 0
      # t.timestamps null: false
    end
  end
end
