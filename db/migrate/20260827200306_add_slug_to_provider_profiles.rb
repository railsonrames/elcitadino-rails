class AddSlugToProviderProfiles < ActiveRecord::Migration[8.0]
  def up
    add_column :provider_profiles, :slug, :string
    ProviderProfile.reset_column_information
    ProviderProfile.find_each do |p|
      base = p.user.name.to_s.parameterize
      base = "provider" if base.blank?
      candidate = base
      suffix = 1
      while ProviderProfile.where(slug: candidate).where.not(id: p.id).exists?
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end
      p.update_column(:slug, candidate)
    end
    change_column_null :provider_profiles, :slug, false
    add_index :provider_profiles, :slug, unique: true
  end

  def down
    remove_index :provider_profiles, :slug
    remove_column :provider_profiles, :slug
  end
end
