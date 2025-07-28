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
  mount ActionCable.server => "/cable"

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
      get :dependencies

      get :sync
    end
    
    resources :projects, constraints: { id: /.*/ }, except: [:index, :new, :create, :destroy] do
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
        get :dependencies

        get :sync
        get :meta
      end
    end
    
    get :projects, to: 'collections#projects'
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
      get :dependencies

      get :sync
      get :meta
    end
  end
  
  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  get '/glossary', to: 'projects#glossary', as: :glossary

  get '/login', to: 'sessions#new', as: :login
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'
  get '/logout', to: 'sessions#destroy'

  root "projects#index"
end
