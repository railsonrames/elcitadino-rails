class ProfileController < ApplicationController
  def security
  end

  def password
    @user = current_user
  end
end
