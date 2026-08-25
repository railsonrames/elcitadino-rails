class Users::RegistrationsController < Devise::RegistrationsController
  # Copied from Devise::RegistrationsController#update (see the gem source)
  # with one change: on validation failure, render the password page the
  # form actually lives on (app/views/profile/password.html.erb) instead
  # of Devise's default `:edit`, which is now the Perfil hub and has no
  # form to show the error on.
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    resource_updated = update_resource(resource, account_update_params)
    yield resource if block_given?

    if resource_updated
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      respond_with resource, location: after_update_path_for(resource)
    else
      clean_up_passwords resource
      set_minimum_password_length
      @user = resource
      render "profile/password", status: :unprocessable_content
    end
  end

  # Devise::RegistrationsController defines this itself (defaulting to the
  # site root), which shadows any override on ApplicationController — the
  # only "update resource" flow right now is the password-change form at
  # Perfil > Segurança > Trocar senha, so send the user back to the Perfil
  # hub afterward instead.
  def after_update_path_for(resource)
    edit_user_registration_path
  end
end
