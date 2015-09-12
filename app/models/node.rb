class Node < ActiveRecord::Base
  belongs_to :user
  has_many :pulses, dependent: :delete_all
	before_save :ensure_authentication_token, :init_token
  validates :title, presence: true

  def dashboard
    ['real_time', 'yearly']
  end

  def pulse_count
    self.pulses.count
  end

  def pulse_first
    q = self.pulses.order(:pulse_time).first
    q.pulse_time.in_time_zone unless q.nil?
  end

  def pulse_last
    q = self.pulses.order(:pulse_time).last
    q.pulse_time.in_time_zone unless q.nil?
  end

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
