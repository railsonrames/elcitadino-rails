require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Elcitadino
  class Application < Rails::Application
    config.load_defaults 8.0

    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.available_locales = [ :"pt-BR", :es, :en, :va ]
    config.i18n.default_locale = :"pt-BR"
    # Valenciano falls back to Spanish first (closer language), then to the
    # app's most complete locale.
    config.i18n.fallbacks = { va: [ :es, :"pt-BR" ], es: [ :"pt-BR" ], en: [ :"pt-BR" ] }

    # DB storage is always UTC (see config.active_record.default_timezone below).
    # This only controls the app-wide default display zone; override per
    # deployment/market via APP_TIMEZONE instead of editing code.
    config.time_zone = ENV.fetch("APP_TIMEZONE", "Madrid")
    config.active_record.default_timezone = :utc

    # Postgres `time` columns (ProviderAvailability#start_time/end_time)
    # have no timezone concept — they're plain wall-clock values. Rails'
    # default (:datetime, :time, :timestamptz) zone-converts :time columns
    # too, which silently shifts what gets written to the DB by the zone
    # offset (a provider's "08:00" is stored as "07:00"): reads/writes
    # through ActiveRecord stay internally consistent either way, but the
    # raw stored value is confusingly wrong when inspected directly (e.g.
    # via a DB client). Excluding :time avoids that entirely.
    config.active_record.time_zone_aware_types = [ :datetime ]
  end
end
