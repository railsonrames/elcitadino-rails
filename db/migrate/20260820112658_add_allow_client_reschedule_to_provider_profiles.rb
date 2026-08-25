class AddAllowClientRescheduleToProviderProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :provider_profiles, :allow_client_reschedule, :boolean, null: false, default: true
  end
end
