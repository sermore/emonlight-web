Rails.application.routes.draw do
  root to: 'visitors#index'
  devise_for :users
  resources :users
  resources :nodes do
  	member do
  		post 'import'
  	end
  end

  get 'stats/:node_id/yearly' => 'stats#yearly', as: :yearly_stats
  get 'stats/:node_id/monthly' => 'stats#monthly', as: :monthly_stats
  get 'stats/:node_id/weekly' => 'stats#weekly', as: :weekly_stats
  get 'stats/:node_id/daily' => 'stats#daily', as: :daily_stats
  get 'stats/:node_id/raw' => 'stats#raw'

  #get 'node/:id/import' => 'node#import', :as :node_import

end
