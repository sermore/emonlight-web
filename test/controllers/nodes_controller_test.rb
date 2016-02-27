require 'test_helper'

class NodesControllerTest < ActionController::TestCase
	include Devise::TestHelpers

  test "read" do
  	node = Node.find_by_title('fixed60')
    assert_equal(Time.zone.parse('2015-05-09 23:59:00'), Pulse.where(node: node).maximum(:pulse_time))
  	assert_difference('Pulse.where(node: node).count') do
    	post :read, token: 'fixed60', time: '2015-05-10 00:00:00 UTC', format: :plain
  	end
  	assert_response(:success, message: "OK")
  	assert_equal(Time.zone.parse('2015-05-10'), Pulse.where(node: node).maximum(:pulse_time))
  	assert_equal(60, Pulse.where(node: node).order(:pulse_time).last.power)

  	assert_difference('Pulse.where(node: node).count') do
    	post :read, node_id: 1, token: 'fixed60', time: '2015-05-10 00:00:01'
  	end
  	assert_response(:success, message: "OK")
  	assert_equal(Time.zone.parse('2015-05-10 00:00:01'), Pulse.where(node: node).maximum(:pulse_time))
  	assert_equal(3600, Pulse.where(node: node).order(:pulse_time).last.power)

  	assert_difference('Pulse.where(node: node).count', 2) do
    	post :read, token: 'fixed60', time: [ '2015-07-01 10:00:05', '2015-07-01 10:00:07'], format: :plain
  	end
  	assert_response(:success, message: "OK")
  	assert_equal(Time.zone.parse('2015-07-01 10:00:07'), Pulse.where(node: node).maximum(:pulse_time))
  	assert_equal(1800, Pulse.where(node: node).order(:pulse_time).last.power)

  end

  test "read unauthenticated" do
  	node = Node.find_by_title('fixed60')
  	assert_difference('Pulse.where(node: node).count', 0) do
    	post :read, token: 'fixed60x', time: '2015-07-01 10:00:00', format: :plain
  	end
  	assert_response(:unauthorized)

  	assert_difference('Pulse.where(node: node).count', 0) do
    	post :read, token: 'fixed60', node_id: 5, time: '2015-07-01 10:00:00', format: :plain
  	end
  	assert_response(:unauthorized)
  end

  test "read epoch" do
  	node = Node.find_by_title('fixed60')
  	t = Time.zone.parse('2015-05-10 10:00:00')
  	assert_difference('Pulse.where(node: node).count', 1) do
    	post :read, token: 'fixed60', epoch_time: "#{t.to_i},#{t.nsec}", format: :plain
  	end
  	assert_response(:success, message: "OK")

  	t += 5
  	t1 = t + 2
  	assert_difference('Pulse.where(node: node).count', 2) do
    	post :read, token: 'fixed60', epoch_time: ["#{t.to_i},#{t.nsec}", "#{t1.to_i},#{t1.nsec}"]
  	end
  	assert_response(:success, message: "OK")
  	assert_equal(t1, Pulse.where(node: node).maximum(:pulse_time))
  	assert_equal(1800, Pulse.where(node: node).order(:pulse_time).last.power)
  end

  test "read fail" do
  	node = Node.find_by_title('fixed60')
  	assert_difference('Pulse.where(node: node).count', 0) do
    	post :read, token: 'fixed60', epoch_time: ''
  	end
  	assert_response(:bad_request, message: "FAIL")

  	assert_difference('Pulse.where(node: node).count', 0) do
    	post :read, token: 'fixed60', time: ['2015-07-01 10:00:00', '', 'XXX']
  	end
  	assert_response(:bad_request, message: "FAIL")
  end

end
