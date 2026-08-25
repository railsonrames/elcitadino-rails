class NotificationPreferencesController < ApplicationController
  before_action :set_preference

  def edit
  end

  def update
    if @preference.update(preference_params)
      redirect_to edit_notification_preference_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_preference
    @preference = current_user.notification_preference || current_user.build_notification_preference
  end

  def preference_params
    params.expect(notification_preference: [ :notify_whatsapp, :notify_push, :notify_email ])
  end
end
