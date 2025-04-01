require 'sidekiq/web'
require 'sidekiq-status/web'

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
end if Rails.env.production?

Rails.application.routes.draw do
  
  mount Rswag::Ui::Engine => '/docs'
  mount Rswag::Api::Engine => '/docs'
  
  mount Sidekiq::Web => "/sidekiq"
  mount PgHero::Engine, at: "pghero"

  namespace :api, :defaults => {:format => :json} do
    namespace :v1 do
      resources :jobs
      resources :collectives, only: [:index, :show] 
      resources :projects, constraints: { id: /.*/ }, only: [:index, :show] do
        collection do
          get :lookup
        end
        member do
          get :ping
        end
      end
    end
  end

  resources :advisories, only: [:index]

  resources :projects, constraints: { id: /.*/ } do
    collection do
      post :lookup
    end
    member do
      get :packages
      get :issues
      get :releases
      get :commits
      get :advisories
    end
  end

  resources :funders, only: [:index, :show]

  resources :collectives do
    member do
      get :funders
      get :projects
      get :packages
      get :issues
      get :releases
      get :commits
      get :advisories
      get :transactions
    end
    collection do
      get :batch
    end
  end
  
  get 'charts/transactions', to: 'charts#transactions', as: :transactions_chart
  get 'charts/issues', to: 'charts#issues', as: :issues_chart
  get 'charts/commits', to: 'charts#commits', as: :commits_chart
  get 'charts/tags', to: 'charts#tags', as: :tags_chart

  resources :sboms

  resources :exports, only: [:index], path: 'open-data'

  get '/charts', to: 'collectives#charts'

  get '/audit/user_owners', to: 'audit#user_owners'
  get '/audit/no_projects', to: 'audit#no_projects'
  get '/audit/no_license', to: 'audit#no_license'
  get '/audit/archived', to: 'audit#archived'
  get '/audit/inactive', to: 'audit#inactive'
  get '/audit/no_funding', to: 'audit#no_funding'
  get '/audit/duplicates', to: 'audit#duplicates'
  get '/audit', to: 'audit#index'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root "collectives#index"
end
