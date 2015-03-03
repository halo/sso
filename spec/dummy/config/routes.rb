Rails.application.routes.draw do

  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end

end
