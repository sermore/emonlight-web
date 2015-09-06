class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

private

	def current_node
		if @current_node
			return @current_node
		end
		if user_signed_in?
			if params[:node_id]
				@current_node = Node.where(id: params[:node_id], user: current_user).first
			else
				@current_node = current_user.node || Node.where(user: current_user).first
			end
		end
		redirect_to root_url if @current_node.nil?
	end

	def node_list
		@nodes = Node.where(user: current_user).order(:title) if @nodes.nil?
	end

	helper_method :current_node, :node_list
end
