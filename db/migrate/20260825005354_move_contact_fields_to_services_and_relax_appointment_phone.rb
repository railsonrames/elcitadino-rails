class MoveContactFieldsToServicesAndRelaxAppointmentPhone < ActiveRecord::Migration[8.0]
  def change
    # The video-call link and phone line are the provider's own, fixed per
    # service (like a business's Zoom room or landline) — not something a
    # client fills in per booking, so they move off appointments.
    remove_column :appointments, :video_call_link, :string
    add_column :services, :video_call_link, :string
    add_column :services, :phone_number, :string

    # appointments.phone_number stays — it's a separate, still-optional
    # field: the client's own contact number, not the provider's line.
  end
end
