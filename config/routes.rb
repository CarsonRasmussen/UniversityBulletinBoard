Rails.application.routes.draw do
  resources :posts do
    resources :comments, only: [ :create ]
    resource :like, only: [ :create, :destroy ]
    resource :saved_post, only: [ :create, :destroy ]
  end
  get "saved_posts", to: "posts#saved", as: :saved_posts
  get "liked_posts", to: "posts#liked", as: :liked_posts
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resource :verification, only: [ :show, :create, :update ]
  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
