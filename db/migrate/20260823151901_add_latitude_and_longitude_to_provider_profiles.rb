class AddLatitudeAndLongitudeToProviderProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :provider_profiles, :latitude, :decimal, precision: 10, scale: 6
    add_column :provider_profiles, :longitude, :decimal, precision: 10, scale: 6
  end
end
