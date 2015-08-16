module ApplicationHelper

	def current_node
		if @current_node
			return @current_node
		end
		if user_signed_in?
			if params[:node_id]
				@current_node = Node.find(params[:node_id])
			else
				@current_node = current_user.node || Node.where(user: current_user).first
			end
		end
	end

	def node_list
		@nodes = Node.where(user: current_user) if @nodes.nil?
	end

end
