module ProviderCategory
  SLUGS = %w[beleza bem_estar fitness casa educacao tecnologia outros].freeze

  ICON_PATHS = {
    "beleza" => "M9.5 3.5 12 6l2.5-2.5M7 9l10 10M17 9 7 19M9 9a2 2 0 1 1-4 0 2 2 0 0 1 4 0Zm12 0a2 2 0 1 1-4 0 2 2 0 0 1 4 0Z",
    "bem_estar" => "M12 21s-7-4.35-9.5-8.5C.9 9.3 2.2 6 5.3 6c1.9 0 3.2 1 3.7 2 .5-1 1.8-2 3.7-2 1.9 0 3.2 1 3.7 2 .5-1 1.8-2 3.7-2 3.1 0 4.4 3.3 2.8 6.5C19 16.65 12 21 12 21Z",
    "fitness" => "M6.5 6.5v11M17.5 6.5v11M2 9.5v5M22 9.5v5M6.5 12h11",
    "casa" => "M4 11 12 4l8 7M6 10v9h5v-5h2v5h5v-9",
    "educacao" => "M12 4 2 9l10 5 10-5-10-5ZM6 11.5V17c0 1.5 2.7 3 6 3s6-1.5 6-3v-5.5",
    "tecnologia" => "M4 6h16v10H4zM9 20h6M12 16v4",
    "outros" => "M12 3v3M12 18v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M3 12h3M18 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"
  }.freeze

  COLORS = {
    "beleza" => "bg-pink-100 text-pink-600",
    "bem_estar" => "bg-emerald-100 text-emerald-600",
    "fitness" => "bg-orange-100 text-orange-600",
    "casa" => "bg-amber-100 text-amber-600",
    "educacao" => "bg-indigo-100 text-indigo-600",
    "tecnologia" => "bg-sky-100 text-sky-600",
    "outros" => "bg-gray-100 text-gray-600"
  }.freeze

  def self.icon_path(slug)
    ICON_PATHS.fetch(slug, ICON_PATHS["outros"])
  end

  def self.color_classes(slug)
    COLORS.fetch(slug, COLORS["outros"])
  end
end
