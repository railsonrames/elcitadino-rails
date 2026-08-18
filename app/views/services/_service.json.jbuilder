json.extract! service, :id, :provider_profile_id, :name, :description, :duration, :price, :created_at, :updated_at
json.url service_url(service, format: :json)
