class Node < ActiveRecord::Base
  belongs_to :user
  has_many :pulses
end
