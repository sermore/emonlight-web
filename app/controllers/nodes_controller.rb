class NodesController < ApplicationController

	skip_before_filter :verify_authenticity_token, :only => :read
	before_filter :authenticate_user_from_token!, only: :read
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

	def read
		# read node from authenticate_from_token
		Time.zone = @current_node.time_zone unless @current_node.nil? || @current_node.time_zone.nil? || @current_node.time_zone.empty?
		data = read_data
		res = Pulse.read(@current_node, data, :read_simple, :read_row_simple) unless data.nil? || data.empty?
		render res.nil? || res == 0 ? { plain: "FAIL", status: 400 } : { plain: "OK" }
	end

	private

	def import
		import = params[:node][:import]
		rows_imported = Pulse.import(@node.id, import.path) unless import.nil?
	end

	# def import
	# 	if params[:id].nil? || params[:file].nil?
	# 		redirect_to node_path, alert: "Import failed." 
	# 	else
	# 		Pulse.import(params[:id], params[:file].path)
	# 		redirect_to node_path, notice: "Import completed."
	# 	end
	# end

	def read_data
		pwr = params[:power].presence
		pwr = [ pwr ] unless pwr.is_a? Enumerable 
		data = params[:time].presence
		if data
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect.with_index do |t, i| 
				break if t.nil? || t.empty?
				[Time.zone.parse(t), pwr.nil? || i >= pwr.length ? nil : pwr[i].to_f]
			end
		elsif data = params[:epoch_time].presence
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect.with_index do |v, i|
				break if v.nil? || v.empty?
				q = v.split(',')
				[Time.zone.at(q[0].to_i + q[1].to_d / 1e9), pwr.nil? || pwr.length <= i ? nil : pwr[i].to_f]
			end
		end
	end		

	def node_params
		params.require(:node).permit(:title, :time_zone, dashboard: [])
	end

	def authenticate_user_from_token!
		env["devise.skip_trackable"] = true
    token = params[:token].presence
    node_id = params[:node_id]
    return unless token
    if (node_id.nil?)
    	res = Node.where(authentication_token: token.to_s)
    	@node = res.first if res.length == 1
    else
    	@node = Node.find_by_id_and_authentication_token(node_id, token.to_s)
		end
		return unless @node
    @current_node = @node
    user = @node.user
    if user
      sign_in user, store: false
    end
  end

end
