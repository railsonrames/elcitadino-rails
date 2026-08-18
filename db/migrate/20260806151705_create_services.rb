class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services do |t|
      t.references :provider_profile, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.integer :duration
      t.decimal :price, precision: 10, scale: 2

      t.timestamps
    end
  end
end
