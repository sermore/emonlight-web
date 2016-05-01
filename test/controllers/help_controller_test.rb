require 'test_helper'

class HelpControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  test "should get getting_started" do
    get :getting_started
    assert_response :success
  end

  test "should get webapp_setup" do
    get :webapp_setup
    assert_response :success
  end

end
