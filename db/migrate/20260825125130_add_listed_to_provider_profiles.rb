class AddListedToProviderProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :provider_profiles, :listed, :boolean, default: true, null: false
  end
end
