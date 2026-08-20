class CreateProviderTimeOffs < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_time_offs do |t|
      t.references :provider_profile, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :reason

      t.timestamps
    end

    add_index :provider_time_offs, [ :provider_profile_id, :starts_on, :ends_on ]
  end
end
