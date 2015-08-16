class AddNodeRefToPulses < ActiveRecord::Migration
  def change
    add_reference :pulses, :node, index: true, foreign_key: true
  end
end
