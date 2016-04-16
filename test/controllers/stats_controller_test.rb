require 'test_helper'

class StatsControllerTest < ActionController::TestCase
	include Devise::TestHelpers

  setup do
  	sign_in User.find_by_email('test2@home.com')
    # @request.env["devise.mapping"] = Devise.mappings[:test1]
    # sign_in FactoryGirl.create(:admin)
  end

  test "real time data" do
  	n = Node.find_by_title(:fixed60)
    get(:real_time_data, {node_id: n.id, time: '2015-05-09 23:58:00' }, format: :json)
    assert_response :success
    assert_equal "[[\"2015-05-09T23:59:00.000+02:00\",60.0]]", @response.body
    n = Node.find_by_title(:fixed20)
    get(:real_time_data, {node_id: n.id, time: '2015-02-28 23:56:00' }, format: :json)
    assert_response :success
    assert_equal "[[\"2015-02-28T23:57:00.000+01:00\",20.0]]", @response.body
    # pp @response.body
  end

  test "daily data" do
  	n = Node.find_by_title(:fixed60)
    get(:daily_data, {node_id: n.id, d: '2015-05-05' }, format: :json)
    assert_response :success
    # pp @response.body
  end

  test "weekly data" do
  	n = Node.find_by_title(:fixed60)
    get(:weekly_data, {node_id: n.id, d: '2015-05-09' }, format: :json)
    assert_response :success
    # pp @response.body
  end

  test "monthly data" do
  	sign_in User.find_by_email('test1@home.com')
  	n = Node.find_by_title(:monthly)
    get(:monthly_data, {node_id: n.id, d: '2015-05-09' }, format: :json)
    assert_response :success
    # pp @response.body
  end

  test "yearly data" do
  	n = Node.find_by_title(:fixed60)
    get(:yearly_data, {node_id: n.id, d: '2015-05-09' }, format: :json)
    assert_response :success
    # pp @response.body
  end

  test "daily per month data" do
    n = Node.find_by_title(:fixed60)
    get(:daily_per_month_data, {node_id: n.id, d: '2015-05-09' }, format: :json)
    assert_response :success
    # pp @response.body
  end

end
