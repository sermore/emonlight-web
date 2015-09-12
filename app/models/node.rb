class Node < ActiveRecord::Base
  belongs_to :user
  has_many :pulses
	before_save :ensure_authentication_token, :init_token
  validates :title, presence: true

  def init_token
    authentication_token |= generate_authentication_token if new_record?
  end

  def ensure_authentication_token
    if authentication_token.blank?
      self.authentication_token = generate_authentication_token
    end
  end

  private
  
  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless Node.where(authentication_token: token).first
    end
  end

end
