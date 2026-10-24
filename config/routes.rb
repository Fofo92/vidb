Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  resource :reconciliation_workbench, only: :show, controller: "reconciliation_workbench/dashboard" do
    get :status
    get :exceptions
    post :refresh
    post :apply
    post :proposals
    post :stop
    resources :families, only: :show, controller: "reconciliation_workbench/families" do
      post :decision, on: :member
      post :arbitrate, on: :member
    end
  end
  resources :genders, except: :show
  resources :language_versions, except: :show
  resource :tv_guide, only: :show
  resource :tv_guide_scheduling_risks, only: :create
  resource :tv_channel_preferences, only: %i[edit update]
  resources :tv_kaffeine_schedules, only: :index
  resources :tv_recording_intents, only: %i[index create destroy] do
    resource :schedule, only: :create, controller: "tv_recording_intent_schedules"
    resource :schedule_title, only: :create, controller: "tv_recording_intent_schedule_titles"
    resource :recording_confirmation, only: %i[create destroy],
             controller: "tv_recording_confirmations"
  end
  resources :records do
    resource :poster, only: %i[show update destroy], controller: "record_posters" do
      post :fetch, on: :member
    end
    resource :states, only: :update, controller: "record_states"
    resource :hierarchy_placement,
             controller: "record_hierarchy_placements",
             only: %i[edit update]
    resource :child_qualification,
             controller: "record_child_qualifications",
             only: %i[edit update]
    member do
      get :new_child
      post :new_child
    end
  end
  resources :media, except: :show
  resources :countries, except: :show
end
