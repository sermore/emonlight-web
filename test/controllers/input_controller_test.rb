require 'test_helper'

class InputControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  test "read" do
    Time.zone = 'Europe/Rome'
    node = Node.find_by_title('fixed60')
    assert_equal(Time.zone.parse('2015-05-09 23:59:00'), Pulse.where(node: node).maximum(:pulse_time))
    assert_difference('Pulse.where(node: Node.find_by_title("fixed60")).count + Pulse.where(node: Node.find_by_title("fixed20")).count', 3) do
      t1 = Time.parse('2015-05-10 00:00:05')
      t2 = Time.parse('2015-05-10 00:00:30')
      t3 = Time.parse('2015-05-10 00:00:00')
      post :read, {nodes: [{k:'fixed60', id: 1068537386, d:[[t1.tv_sec, t1.tv_nsec, 1300.0], [t2.tv_sec, t2.tv_nsec, 1000.0]]},{k: 'fixed20', id: 467424045, d:[[t3.tv_sec, t3.tv_nsec, 1200]]}]}, format: :json
    end
    assert_response(:success, message: "OK")
  end

  test "read fail 1" do
    Time.zone = 'Europe/Rome'
    node = Node.find_by_title('fixed60')
    assert_equal(Time.zone.parse('2015-05-09 23:59:00'), Pulse.where(node: node).maximum(:pulse_time))
    assert_difference('Pulse.where(node: Node.find_by_title("fixed60")).count + Pulse.where(node: Node.find_by_title("fixed20")).count', 0) do
      t1 = Time.parse('2015-05-10 00:00:05')
      t2 = Time.parse('2015-05-10 00:00:30')
      t3 = Time.parse('2015-05-10 00:00:00')
      post :read, {nodes: [{k:'fixed60', id: 1068537386, d:[[t1.tv_sec, t1.tv_nsec, 1300.0], [t2.tv_sec, t2.tv_nsec, 1000.0]]},{k: 'fixed20', id: 4, d:[[t3.tv_sec, t3.tv_nsec, 1200]]}]}, format: :json
    end
    assert_response(400, message: "FAIL")
  end

  test "read fail 2" do
    Time.zone = 'Europe/Rome'
    node = Node.find_by_title('fixed60')
    assert_equal(Time.zone.parse('2015-05-09 23:59:00'), Pulse.where(node: node).maximum(:pulse_time))
    assert_difference('Pulse.where(node: Node.find_by_title("fixed60")).count + Pulse.where(node: Node.find_by_title("fixed20")).count', 0) do
      t1 = Time.parse('2015-05-10 00:00:05')
      t2 = Time.parse('2015-05-10 00:00:30')
      t3 = Time.parse('2015-05-10 00:00:00')
      post :read, {nodes: [{k:'fixed60', id: 1068537386, d:[[t1.tv_sec, 1300.0], [t2.tv_sec, t2.tv_nsec, 1000.0]]},{k: 'fixed20', d:[[t3.tv_sec, t3.tv_nsec, 1200]]}]}, format: :json
    end
    assert_response(400, message: "FAIL")
  end

  test "read fail 3" do
    Time.zone = 'Europe/Rome'
    node = Node.find_by_title('fixed60')
    assert_equal(Time.zone.parse('2015-05-09 23:59:00'), Pulse.where(node: node).maximum(:pulse_time))
    assert_difference('Pulse.where(node: Node.find_by_title("fixed60")).count + Pulse.where(node: Node.find_by_title("fixed20")).count', 0) do
      t1 = Time.parse('2015-05-10 00:00:05')
      t2 = Time.parse('2015-05-10 00:00:30')
      t3 = Time.parse('2015-05-10 00:00:00')
      post :read, {nodes: [{k:'fixed60X', id: '1068537386', d:[[t1.tv_sec, t1.tv_nsec, 1300.0], [t2.tv_sec, t2.tv_nsec, 1000.0]]},{k: 'fixed20', d:[[t3.tv_sec, t3.tv_nsec, 1200]]}]}, format: :json
    end
    assert_response(400, message: "FAIL")
  end

end
