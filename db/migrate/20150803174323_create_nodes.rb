class CreateNodes < ActiveRecord::Migration
  def change
    create_table :nodes do |t|
      t.string :title
      t.integer :pulses_per_kwh, default: 1000
      t.string :authentication_token
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
