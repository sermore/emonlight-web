class NodesController < ApplicationController
	before_action :authenticate_user!

	def new
		@node = Node.new(user: current_user)
	end

	def create
		@node = Node.new(node_params)
		@node.user = current_user
		if @node.save
			redirect_to(@node, notice: "Node '#{@node.title}' successfully created.")
			@nodes = nil
		end
	end

	def show
		@node = Node.find(params[:id])
		@current_node = @node
	end

	def import
		if params[:id].nil? || params[:file].nil?
			redirect_to node_path, alert: "Import failed." 
		else
			Pulse.import(params[:id], params[:file].path)
			redirect_to node_path, notice: "Import completed."
		end
	end

	private

	def node_params
		params.require(:node).permit(:title)
	end

end
