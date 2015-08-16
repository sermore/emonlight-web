class AddNodeRefToUsers < ActiveRecord::Migration
  def change
    add_reference :users, :node, index: true, foreign_key: true
  end
end
