class InputController < ApplicationController
  skip_before_filter :verify_authenticity_token, only: :read

  def read
    p = params[:nodes]
    res = nil
    fail = false
    if !p.nil? && !p.empty?
      nodes = p.map do |n|
        k = n[:k]
        node = Node.find_by_authentication_token(k) unless k.nil?
        d = n[:d]
        nid = n[:id]
        unless n.nil? || node.nil? || (nid.nil? ? false : node.id != nid.to_i) || d.empty?
          {node: node, data: d}
        else
          fail = true
        end
      end
      res = Pulse.read_nodes(nodes) unless fail || nodes.empty?
    end
    render fail || res.nil? || res == 0 ? { plain: "FAIL", status: 400 } : { plain: "OK" }
  end

  private

  def input_params
    params.require(:nodes)
  end

end
