class NodesController < ApplicationController

	before_filter :authenticate_user!

	def index
		node_list
	end

	def new
		@node = Node.new(user: current_user)
		render 'edit'
	end

	def edit
		@node = Node.where(id: params[:id], user: current_user).first
		redirect_to(root_url) and return if @node.nil?
		@current_node = @node
		render 'edit'
	end

	def update
		@node = Node.where(id: params[:id], user: current_user).first
		if @node.update_attributes(node_params)
			rows_imported = import
			redirect_to nodes_url, notice: "Node '#{@node.title}' successfully updated" + (rows_imported.nil? ? "" : " and imported #{rows_imported} rows") + "."
		else
			render 'edit'
		end
	end

	def create
		@node = Node.new(node_params)
		@node.user = current_user
		if @node.save
			rows_imported = import
			redirect_to nodes_url, notice: "Node '#{@node.title}' successfully created" + (rows_imported.nil? ? "" : " and imported #{rows_imported} rows") + "."
			@nodes = nil
		else
			render 'edit'
		end
	end
	
	def destroy
		@node = Node.where(id: params[:id], user: current_user).first
		redirect_to(root_url) and return if @node.nil?
		@node.destroy
		flash[:success] = "Node deleted"
		redirect_to nodes_url
  end

	def show
		# @node = Node.where(id: params[:id], user: current_user).first
		# redirect_to root_url if @node.nil?
		# @current_node = @node
		edit
	end

	def import
		pn = Node.new(node_params)
		clear_on_input = ("1" == pn.clear_on_import ? true : false)
		rows_imported = Pulse.import(@node.id, pn.import.path, clear_on_input) unless pn.import.nil?
	end

	# def import
	# 	if params[:id].nil? || params[:file].nil?
	# 		redirect_to node_path, alert: "Import failed." 
	# 	else
	# 		Pulse.import(params[:id], params[:file].path)
	# 		redirect_to node_path, notice: "Import completed."
	# 	end
	# end

	def export
		id = params[:id]
		send_data Pulse.export(id), filename: "export_#{id}.csv"
	end

	private

	def node_params
		params.require(:node).permit(:title, :pulses_per_kwh, :time_zone, :clear_on_import, :import, dashboard: [])
	end

end
