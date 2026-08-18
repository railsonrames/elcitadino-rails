json.extract! appointment, :id, :client_id, :provider_profile_id, :service_id, :scheduled_at, :status, :modality, :notes, :created_at, :updated_at
json.url appointment_url(appointment, format: :json)
