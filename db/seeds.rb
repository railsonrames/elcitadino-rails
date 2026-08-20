# Limpar dados antigos
Appointment.destroy_all
Service.destroy_all
ProviderProfile.destroy_all
User.destroy_all

# 1. Criar um Prestador
provider_user = User.create!(
  name: "Dr. Silva",
  email: "silva@example.com",
  password: "password123",
  role: :provider
)

profile = ProviderProfile.create!(
  user: provider_user,
  bio: "Especialista em fisioterapia",
  address: "Calle Mayor, 10",
  city: "Alicante",
  category: "bem_estar"
)

# 2. Criar um Serviço
service = Service.create!(
  provider_profile: profile,
  name: "Consulta Inicial",
  duration: 60,
  price: 150.00
)

# 3. Criar um Cliente e um Agendamento
client_user = User.create!(
  name: "João Cliente",
  email: "joao@example.com",
  password: "password123",
  role: :client
)

Appointment.create!(
  client: client_user,
  provider_profile: profile,
  service: service,
  scheduled_at: (Date.tomorrow.in_time_zone).change(hour: 10, min: 0),
  status: :confirmed,
  modality: :in_person
)

puts "Seeds criados com sucesso!"
