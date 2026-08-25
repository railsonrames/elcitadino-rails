class AddServiceIdToProviderAvailabilities < ActiveRecord::Migration[8.0]
  def change
    add_reference :provider_availabilities, :service, null: true, foreign_key: true
  end
end
