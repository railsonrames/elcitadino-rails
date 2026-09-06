class AddPaymentConfirmationToServicesAndAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :services, :requires_payment_confirmation, :boolean, default: false, null: false
    add_column :services, :deposit_amount, :decimal
    add_column :services, :payment_instructions, :text
    add_column :services, :payment_confirmation_window_minutes, :integer, default: 120, null: false

    add_column :appointments, :payment_confirmation_deadline_at, :datetime
  end
end
