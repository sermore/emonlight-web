Rails.application.routes.draw do

  authenticated :user do
    root :to => "nodes#index", as: :authenticated_root
  end
  root to: 'visitors#index'
  devise_for :users
  resources :users
  resources :nodes do
  	member do
  		post 'import'
  	end
    collection do
      post 'read' 
    end
  end

  get 'stats/:node_id/dashboard' => 'stats#dashboard', as: :dashboard_stats
  get 'stats/:node_id/yearly_data' => 'stats#yearly_data', as: :yearly_data_stats
  # get 'stats/:node_id/monthly' => 'stats#chart', as: :monthly_stats
  get 'stats/:node_id/monthly_data' => 'stats#monthly_data', as: :monthly_data_stats
  # get 'stats/:node_id/weekly' => 'stats#chart', as: :weekly_stats
  get 'stats/:node_id/weekly_data' => 'stats#weekly_data', as: :weekly_data_stats
  # get 'stats/:node_id/daily' => 'stats#chart', as: :daily_stats
  get 'stats/:node_id/daily_data' => 'stats#daily_data', as: :daily_data_stats
  # get 'stats/:node_id/real_time' => 'stats#chart', as: :real_time_stats
  get 'stats/:node_id/real_time_data' => 'stats#real_time_data', as: :real_time_data_stats
  get 'stats/:node_id/:chart' => 'stats#chart', as: :chart_stats, constraints: { chart: /yearly|monthly|weekly|daily|real_time/}

  #get 'node/:id/import' => 'node#import', :as :node_import

end
