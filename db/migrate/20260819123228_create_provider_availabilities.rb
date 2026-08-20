class CreateProviderAvailabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_availabilities do |t|
      t.references :provider_profile, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :modality

      t.timestamps
    end

    add_index :provider_availabilities, [ :provider_profile_id, :day_of_week ]
  end
end
