require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Elcitadino
  class Application < Rails::Application
    config.load_defaults 8.0

    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.available_locales = [:"pt-BR", :es, :en]
    config.i18n.default_locale = :"pt-BR"
    config.time_zone = "Madrid"
  end
end
