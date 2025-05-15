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

  resources :collections do
    member do
      get :projects
      get :packages
      get :issues
      get :releases
      get :commits
      get :advisories

      get :productivity
      get :responsiveness
      get :finance
      get :engagement
      get :adoption
      get :dependency

    end
  end

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

      get :productivity
      get :responsiveness
      get :finance
      get :engagement
      get :adoption
      get :dependency

      get :sync
      get :meta
    end
  end
  
  get 'charts/transactions', to: 'charts#transactions', as: :transactions_chart
  get 'charts/issues', to: 'charts#issues', as: :issues_chart
  get 'charts/commits', to: 'charts#commits', as: :commits_chart
  get 'charts/tags', to: 'charts#tags', as: :tags_chart

  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  get '/glossary', to: 'projects#glossary', as: :glossary

  root "projects#index"
end
