class NodesController < ApplicationController

	skip_before_filter :verify_authenticity_token, :only => :read
	before_filter :authenticate_user_from_token!, only: :read
	before_filter :authenticate_user!

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
		@node = Node.where(id: params[:id], user: current_user).first
		redirect_to root_url if @node.nil?
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
		# read node from authenticate_from_token
		data = read_data
		res = Pulse.read(@current_node, data, :read_simple, :read_row_simple) unless data.nil? || data.empty?
		render res.nil? || res == 0 ? { plain: "FAIL", status: 400 } : { plain: "OK" }
	end

	private

	def read_data
		pwr = params[:power].presence
		pwr = [ pwr ] unless pwr.is_a? Enumerable 
		data = params[:time].presence
		if data
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect.with_index do |t, i| 
				break if t.nil? || t.empty?
				[Time.parse(t), pwr.nil? || i >= pwr.length ? nil : pwr[i].to_f]
			end
		elsif data = params[:epoch_time].presence
			data = [ data ] unless data.is_a? Enumerable
			data = data.collect.with_index do |v, i|
				break if v.nil? || v.empty?
				q = v.split(',')
				[Time.at(q[0].to_i, q[1].to_f/1000), pwr.nil? || pwr.length <= i ? nil : pwr[i].to_f]
			end
		end
	end		

	def node_params
		params.require(:node).permit(:title)
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
