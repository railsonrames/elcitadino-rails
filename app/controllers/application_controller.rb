class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  around_action :switch_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def switch_locale(&action)
    locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s))
    I18n.with_locale(locale || I18n.default_locale, &action)
  end

  def default_url_options
    # Always supply the :locale key (nil for the default locale, so it's
    # dropped from the URL) rather than omitting it — omitting it entirely
    # causes positional route helpers like `appointment_path(@appointment)`
    # to bind the argument to the optional :locale segment instead of :id.
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :role ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  def after_sign_up_path_for(resource)
    resource.provider? ? new_provider_profile_path : providers_path
  end

  def after_sign_in_path_for(resource)
    return providers_path if resource.client?

    resource.provider_profile.present? ? dashboard_path : new_provider_profile_path
  end
end
