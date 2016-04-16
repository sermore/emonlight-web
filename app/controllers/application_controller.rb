class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

private

	def current_node
		if @current_node
			return @current_node
		end
		if user_signed_in? && params[:node_id]
			@current_node = Node.where(id: params[:node_id], user: current_user).first
			Time.zone = @current_node.time_zone unless @current_node.nil? || @current_node.time_zone.nil? || @current_node.time_zone.empty?
			@current_node
		end
	end

	def node_list
		@nodes ||= Node.where(user: current_user).order(:title)
	end

	def verify_current_node
		redirect_to root_path if current_node.nil?
	end

	helper_method :current_node, :node_list
end
