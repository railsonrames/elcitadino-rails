class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :client, null: false, foreign_key: {to_table: :users}
      t.references :provider_profile, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.datetime :scheduled_at
      t.integer :status
      t.integer :modality
      t.text :notes

      t.timestamps
    end
  end
end
