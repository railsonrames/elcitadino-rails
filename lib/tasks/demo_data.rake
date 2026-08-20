namespace :demo do
  desc "Seed 34 demo providers with varied, realistic availability schedules for manual testing"
  task providers: :environment do
    DemoData::ProviderGenerator.new.run
  end
end

module DemoData
  FIRST_NAMES = %w[
    Mateus Sofia Rafael Beatriz Lucas Camila Gabriel Larissa Bruno Fernanda
    Diego Juliana Thiago Mariana Felipe Renata Andre Patricia Vinicius Carolina
    Rodrigo Aline Marcelo Vanessa Leonardo Priscila Eduardo Natalia Gustavo Isabela
    Ricardo Bianca Fabio Daniela
  ].freeze

  LAST_NAMES = %w[
    Silva Santos Oliveira Souza Pereira Costa Rodrigues Almeida Nascimento Lima
    Araujo Fernandes Carvalho Gomes Martins Rocha Ribeiro Barbosa Teixeira Moreira
    Cardoso Vieira Cavalcanti Dias Castro Andrade Nunes Freitas Correia Machado
    Pinto Moura Reis Monteiro
  ].freeze

  MONDAY_TO_FRIDAY = (1..5)
  MONDAY_TO_SATURDAY = (1..6)
  TUESDAY_TO_SATURDAY = (2..6)
  WEEKEND = [ 0, 6 ].freeze

  SERVICE_TEMPLATES = {
    "beleza" => [ [ "Corte de Cabelo", 30, 15..35 ], [ "Barba", 20, 10..20 ], [ "Manicure", 45, 20..30 ] ],
    "bem_estar" => [ [ "Massagem Relaxante", 60, 35..60 ], [ "Sessão de Spa", 90, 50..90 ] ],
    "fitness" => [ [ "Treino Personal", 60, 25..45 ], [ "Aula de Yoga", 60, 15..30 ] ],
    "casa" => [ [ "Reparo Hidráulico", 60, 30..60 ], [ "Instalação Elétrica", 90, 40..80 ], [ "Limpeza Residencial", 120, 40..70 ] ],
    "educacao" => [ [ "Aula Particular", 60, 20..40 ], [ "Reforço Escolar", 60, 15..30 ] ],
    "tecnologia" => [ [ "Suporte Técnico", 45, 25..45 ], [ "Instalação de Software", 30, 15..30 ] ],
    "outros" => [ [ "Consultoria", 60, 30..60 ] ]
  }.freeze

  WEEKLY_PATTERNS = [
    { days: MONDAY_TO_FRIDAY, windows: [ [ [ 9, 0 ], [ 18, 0 ] ] ] },
    { days: MONDAY_TO_FRIDAY, windows: [ [ [ 8, 0 ], [ 17, 0 ] ] ] },
    { days: MONDAY_TO_SATURDAY, windows: [ [ [ 9, 0 ], [ 19, 0 ] ] ] },
    { days: WEEKEND, windows: [ [ [ 10, 0 ], [ 18, 0 ] ] ] },
    { days: MONDAY_TO_FRIDAY, windows: [ [ [ 9, 0 ], [ 13, 0 ] ], [ [ 15, 0 ], [ 19, 0 ] ] ] },
    { days: TUESDAY_TO_SATURDAY, windows: [ [ [ 10, 0 ], [ 19, 0 ] ] ] }
  ].freeze

  PASSWORD = "password123"

  class ProviderGenerator
    def run
      emails = []

      emails << build_plumber
      emails << build_relocation_consultant

      # Each provider gets its own Random instance (seeded from its index)
      # rather than sharing one across the loop — a shared, sequentially
      # consumed RNG would desync between runs whenever an earlier
      # provider's find_or_create short-circuits (already seeded) and
      # skips rand() calls a fresh insert would have made, which then
      # shifts every later provider's "random" name/schedule and breaks
      # idempotency (reruns would create duplicates under new emails).
      32.times { |i| emails << build_randomized(index: i, rng: Random.new(42 + i)) }

      puts "\nSeeded #{emails.size} demo providers (password: #{PASSWORD} for all):"
      emails.each { |email| puts "  #{email}" }
    end

    private

    def build_plumber
      user = find_or_create_user(email: "encanador.demo@example.com", name: "Paulo Encanador")
      profile = find_or_create_profile(user, category: "casa", city: "Alicante",
        bio: "Encanador com mais de 10 anos de experiência em reparos residenciais.")

      add_services(profile, category: "casa", rng: Random.new(1))
      add_weekly_rule(profile, days: MONDAY_TO_FRIDAY, windows: [ [ [ 8, 0 ], [ 18, 0 ] ] ])
      add_time_off(profile, starts_on: Date.new(2026, 8, 24), ends_on: Date.new(2026, 8, 30))

      user.email
    end

    def build_relocation_consultant
      user = find_or_create_user(email: "relocation.demo@example.com", name: "Elena Relocation")
      profile = find_or_create_profile(user, category: "outros", city: "Valência",
        bio: "Consultoria completa de relocation: apoio na mudança para Espanha, do início ao fim.")

      if profile.services.empty?
        profile.services.create!(name: "Consultoria via Vídeo", description: "Primeira conversa e planejamento, por videochamada.", duration: 45, price: 40)
        profile.services.create!(name: "Visita Presencial a Imóveis", description: "Acompanhamento presencial em visitas a casas/apartamentos.", duration: 90, price: 90)
      end

      add_weekly_rule(profile, days: (2..5), windows: [ [ [ 9, 0 ], [ 12, 0 ] ] ], modality: "video")
      add_weekly_rule(profile, days: (2..5), windows: [ [ [ 16, 0 ], [ 21, 0 ] ] ], modality: "in_person")

      user.email
    end

    # Every rand() call happens unconditionally, in a fixed order, before
    # any database read/write — so the exact same random choices are made
    # on a rerun regardless of what already exists, which is what lets the
    # find_or_create/"skip if already present" guards below work at all.
    def build_randomized(index:, rng:)
      category = ProviderCategory::SLUGS[index % ProviderCategory::SLUGS.size]
      first_name = FIRST_NAMES[rng.rand(FIRST_NAMES.size)]
      last_name = LAST_NAMES[rng.rand(LAST_NAMES.size)]
      city = %w[Alicante Valência].sample(random: rng)

      templates = SERVICE_TEMPLATES.fetch(category)
      chosen_services = templates.sample(rng.rand(1..[ 2, templates.size ].min), random: rng)
        .map { |name, duration, price_range| [ name, duration, rng.rand(price_range) ] }

      pattern = WEEKLY_PATTERNS.sample(random: rng)

      has_time_off = rng.rand < 0.3
      time_off_start = Date.current + rng.rand(5..55) if has_time_off
      time_off_end = time_off_start + rng.rand(3..7) if has_time_off

      email = "#{first_name.downcase}.#{last_name.downcase}#{index}@example.com"
      user = find_or_create_user(email: email, name: "#{first_name} #{last_name}")
      profile = find_or_create_profile(user, category: category, city: city,
        bio: "Profissional de #{category.tr("_", " ")} com atendimento de qualidade.")

      if profile.services.empty?
        chosen_services.each do |name, duration, price|
          profile.services.create!(name: name, description: "#{name} realizado por profissional qualificado.", duration: duration, price: price)
        end
      end

      add_weekly_rule(profile, days: pattern[:days], windows: pattern[:windows])
      add_time_off(profile, starts_on: time_off_start, ends_on: time_off_end) if has_time_off

      user.email
    end

    def find_or_create_user(email:, name:)
      User.find_or_create_by!(email: email) do |user|
        user.name = name
        user.password = PASSWORD
        user.role = :provider
      end
    end

    def find_or_create_profile(user, category:, city:, bio:)
      ProviderProfile.find_or_create_by!(user: user) do |profile|
        profile.category = category
        profile.city = city
        profile.address = "Rua Principal, #{rand(1..200)}"
        profile.bio = bio
      end
    end

    def add_services(profile, category:, rng:)
      return if profile.services.any?

      templates = SERVICE_TEMPLATES.fetch(category)
      templates.sample(rng.rand(1..[ 2, templates.size ].min), random: rng).each do |name, duration, price_range|
        profile.services.create!(name: name, description: "#{name} realizado por profissional qualificado.",
          duration: duration, price: rng.rand(price_range))
      end
    end

    def add_weekly_rule(profile, days:, windows:, modality: nil)
      return if profile.availabilities.any? { |a| days.to_a.include?(a.day_of_week) && a.modality == modality }

      days.each do |day|
        windows.each do |start_hm, end_hm|
          profile.availabilities.create!(
            day_of_week: day,
            start_time: format("%02d:%02d", *start_hm),
            end_time: format("%02d:%02d", *end_hm),
            modality: modality
          )
        end
      end
    end

    def add_time_off(profile, starts_on:, ends_on:)
      return if profile.time_offs.any? { |t| t.starts_on == starts_on && t.ends_on == ends_on }

      profile.time_offs.create!(starts_on: starts_on, ends_on: ends_on)
    end
  end
end
