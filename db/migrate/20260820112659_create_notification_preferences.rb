class CreateNotificationPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :notify_whatsapp, null: false, default: true
      t.boolean :notify_push, null: false, default: true
      t.boolean :notify_email, null: false, default: true

      t.timestamps
    end
  end
end
