Rails.application.routes.draw do

  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end

  resources :sessions, only: [:new, :create]
  get '/logout(/:passport_id)', to: 'sessions#logout', as: :logout

  root to: 'home#index'

end
