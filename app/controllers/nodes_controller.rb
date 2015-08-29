class NodesController < ApplicationController

	before_filter :authenticate_user_from_token!, only: :read
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

	def read
		data = read_data
		res = Pulse.read(@current_node, data, :read_simple, :read_row_simple) unless data.nil? || data.empty?
		render res.nil? || res == 0 ? { plain: "FAIL", status: 400 } : { plain: "OK" }
	end

	private

	def read_data
		data = params[:time].presence
		if data
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect do |t| 
				break if t.nil? || t.empty?
				Time.parse(t)
			end
		elsif data = params[:epoch_time].presence
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect do |v|
				break if v.nil? || v.empty?
				q = v.split(',')
				Time.at(q[0].to_i, q[1].to_i)
			end
		end
	end		

	def node_params
		params.require(:node).permit(:title)
	end

	def authenticate_user_from_token!
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
