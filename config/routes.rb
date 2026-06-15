require 'sidekiq/web'

Rails.application.routes.draw do
  Spree::Core::Engine.add_routes do
    # Admin authentication
    devise_for(
      Spree.admin_user_class.model_name.singular_route_key,
      class_name: Spree.admin_user_class.to_s,
      controllers: {
        sessions: 'spree/admin/user_sessions',
        passwords: 'spree/admin/user_passwords'
      },
      skip: :registrations,
      path: :admin_user,
      router_name: :spree
    )
  end

  namespace :pharma do
    namespace :admin do
      namespace :api do
        namespace :v1 do
          resources :drug_masters, only: %i[index show create update]
          resources :drug_batch_stocks, only: %i[create update]
          resources :order_allocations, only: :create
          resources :pharmacies, only: %i[index show] do
            patch :review, on: :member
          end
          resources :supplier_offers, only: %i[index show create update] do
            resources :regions, only: :create, controller: :supplier_offer_regions
          end
          resources :supplier_offer_regions, only: :update
          resources :suppliers, only: %i[index show create update] do
            resources :licenses, only: :create, controller: :supplier_licenses
            resources :warehouses, only: :create, controller: :supplier_warehouses
          end
          resources :supplier_licenses, only: :update
          resources :supplier_warehouses, only: :update
          resources :pharmacy_licenses, only: [] do
            patch :review, on: :member
          end
          resource :supplier_visibility_config, only: %i[show update]
        end
      end
    end

    namespace :api do
      namespace :v1 do
        resources :pharmacies, only: :create, param: :code do
          resources :licenses, only: :create, controller: :pharmacy_licenses
        end

        resources :drugs, only: :index do
          get :offers, on: :member
        end
      end
    end
  end

  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option here, as Spree relies on it being
  # the default of "spree".
  mount Spree::Core::Engine, at: '/'
  devise_for :admin_users, class_name: "Spree::AdminUser"
  devise_for :users, class_name: "Spree::User"

  # Sidekiq Web UI
  authenticate Spree.admin_user_class.model_name.singular_route_key.to_sym, lambda(&:spree_admin?) do
    mount Sidekiq::Web => "/sidekiq" # access it at http://localhost:3000/sidekiq
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect('/admin')
end
