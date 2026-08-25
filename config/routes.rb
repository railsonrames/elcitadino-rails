Rails.application.routes.draw do
  # Fixed, unprefixed URLs hit directly by the browser/OS/load balancer —
  # never reached via link_to, so they stay outside the locale scope.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "up" => "rails/health#show", as: :rails_health_check

  scope "(:locale)", locale: /pt-BR|es|en|va/ do
    devise_for :users, controllers: { registrations: "users/registrations" }

    root "providers#index"

    resources :providers, only: [ :index, :show ] do
      collection { get :nearby }
      resources :appointments, only: [ :new, :create ]
    end

    resource :provider_profile, only: [ :new, :create, :edit, :update ] do
      resources :services, only: [ :new, :create, :edit, :update, :destroy ]
      resources :time_offs, only: [ :create, :destroy ], controller: "provider_time_offs"
      resource :setting, only: [ :edit, :update ], controller: "provider_settings"
      resource :schedule, only: [ :edit, :update ], controller: "provider_schedules"
    end

    resource :notification_preference, only: [ :edit, :update ]

    get "profile/security", to: "profile#security", as: :profile_security
    get "profile/security/password", to: "profile#password", as: :profile_security_password

    resource :dashboard, controller: "dashboard", only: [ :show ]

    resources :appointments, only: [ :index, :show, :update ] do
      member do
        get :reschedule
      end
    end
  end
end

# Base fallback for URL generation outside a request cycle (mailers, jobs,
# tests calling path helpers directly) — without this, positional route
# helpers like `appointment_path(@appointment)` bind their argument to the
# optional :locale segment instead of :id, since it's otherwise unset.
# ApplicationController#default_url_options overrides this per-request.
Rails.application.routes.default_url_options[:locale] = nil
