# Elcitadino — Guia de Contexto para Claude Code

> Este arquivo é lido automaticamente pelo Claude Code no início de cada sessão.
> As decisões abaixo são **finais** — não reabrir discussão técnica sobre elas.

## 1. Visão Geral

Sistema de gestão de agendamentos (citas) em modelo de marketplace, conectando
clientes finais a prestadores de serviços (barbearias, salões de beleza, spas,
personal trainers etc.). Foco inicial no mercado espanhol (Alicante e Valência),
com suporte nativo a múltiplos idiomas e fusos horários.

Este projeto também é peça de portfólio profissional — o código deve refletir
maturidade arquitetural: testes RSpec robustos, Clean Code, documentação clara.

## 2. Stack e Decisões Arquiteturais (não reabrir)

- **Framework:** Ruby on Rails 7.1+, arquitetura **Monolítica**
- **Frontend:** MVC completo com **ERB** + **Hotwire** (Turbo + Stimulus).
  React foi formalmente descartado para este projeto.
- **Banco de dados:** PostgreSQL
- **Estilização:** Tailwind CSS (`tailwindcss-rails`)
- **Autenticação:** Devise
- **i18n:** locales obrigatórios `pt-BR`, `es`, `en`, `va` (Valenciano)
- **Timezone:** armazenamento estrito em **UTC** no banco. Conversão para
  horário local ocorre **apenas na camada de View** (`.in_time_zone(user_timezone)`)
- **Distribuição:** PWA nativa (manifest.json + service-worker.js via Asset Pipeline)
- **Mobile:** prioridade para **Turbo Native** (reaproveitando views existentes)

## 3. Modelagem de Dados

| Model | Associações | Campos principais |
|---|---|---|
| `User` | gerenciado pelo Devise | `role` (enum: `client: 0`, `provider: 1`) |
| `ProviderProfile` | `belongs_to :user` | `bio`, `address`, `city` |
| `Category` | — | `name`, `icon` |
| `Service` | `belongs_to :provider_profile`, `belongs_to :category` | `name`, `description`, `duration` (min), `price` (decimal) |
| `Appointment` | `belongs_to :provider_profile`, `belongs_to :service`, `belongs_to :client` (→ `users`) | `scheduled_at` (datetime UTC), `status` (enum: `pending/confirmed/cancelled/completed`), `modality` (enum: `in_person/home/phone/video`), `client_name`, `client_email`, `client_phone`, `notes` |
| `Review` | `belongs_to :appointment` | `rating` (integer), `comment` |

⚠️ **Enums** — manter estes valores fixos ao gerar migrations/models:
- `User#role`: `client: 0`, `provider: 1`
- `Appointment#status`: `pending: 0`, `confirmed: 1`, `cancelled: 2`, `completed: 3`
- `Appointment#modality`: `in_person: 0`, `home: 1`, `phone: 2`, `video: 3`

## 4. Setup Inicial

```bash
rails new elcitadino --database=postgresql --css=tailwind

bundle add devise devise-i18n rails-i18n hotwire-rails simple_form kaminari
bundle add rspec-rails --group "development, test"

rails generate rspec:install
rails generate simple_form:install --tailwind

rails generate devise User role:integer
rails generate model ProviderProfile user:references bio:text address:string city:string
rails generate model Category name:string icon:string
rails generate model Service provider_profile:references category:references name:string description:text duration:integer price:decimal{10,2}
rails generate model Appointment provider_profile:references service:references client:references{to_table:users} scheduled_at:datetime status:integer modality:integer client_name:string client_email:string client_phone:string notes:text
rails generate model Review appointment:references rating:integer comment:text
```

## 5. Configurações Globais

### `config/application.rb`
```ruby
config.time_zone = 'UTC'
config.active_record.default_timezone = :utc
config.i18n.available_locales = [:'pt-BR', :es, :en, :va]
config.i18n.default_locale = :'pt-BR'
```

### `config/routes.rb`
```ruby
scope "(:locale)", locale: /pt-BR|es|en|va/ do
  devise_for :users
  root "home#index"

  resources :providers, only: [:index, :show] do
    resources :appointments, only: [:new, :create]
  end

  resource :dashboard, controller: 'dashboard', only: [:show]
  resources :appointments, only: [:index, :show, :update]
end
```

## 6. Regras de Negócio e UX

1. **Dashboard do Prestador:** métricas em tempo real.
   - Agendamentos do dia: `scheduled_at` entre `beginning_of_day` e `end_of_day`
   - Receita mensal: soma do `price` dos serviços de agendamentos com status `confirmed`
2. **Tratamento de horários:** frontend captura timezone do usuário → salva em UTC →
   exibe com `.in_time_zone(user_timezone)`
3. **PWA:** `manifest.json` e `service-worker.js` servidos via Asset Pipeline,
   garantindo instalabilidade em dispositivos móveis.

## 7. Convenções de Desenvolvimento (preencher/ajustar conforme o projeto evolui)

- Comandos de teste: `bin/rails test` ou `bundle exec rspec`
- Toda feature nova deve vir acompanhada de specs RSpec
- Commits pequenos e descritivos por ciclo de trabalho
- Se alguma sugestão contrariar as decisões da seção 2, apontar de volta para este arquivo