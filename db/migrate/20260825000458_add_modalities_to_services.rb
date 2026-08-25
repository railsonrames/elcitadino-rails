class AddModalitiesToServices < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :modalities, :string, array: true, default: [], null: false
  end
end
