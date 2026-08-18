class CreateProviderProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :provider_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.text :bio
      t.string :address
      t.string :city
      t.string :category

      t.timestamps
    end
  end
end
