module DateParams
  extend ActiveSupport::Concern

  private

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end
end
