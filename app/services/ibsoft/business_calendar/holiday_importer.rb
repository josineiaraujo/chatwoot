class Ibsoft::BusinessCalendar::HolidayImporter
  VALID_STATE_CODES = %w[AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO].freeze
  VALID_LEVELS = {
    'nacional' => 'national',
    'national' => 'national',
    'estadual' => 'state',
    'state' => 'state'
  }.freeze

  def initialize(calendar:, year:, import_options: {}, client: nil)
    options = import_options.to_h.symbolize_keys

    @calendar = calendar
    @year = Integer(year)
    @state_code = options[:state_code].to_s.upcase.presence
    raise ArgumentError, 'invalid_state_code' if @state_code.present? && VALID_STATE_CODES.exclude?(@state_code)

    @include_optional = ActiveModel::Type::Boolean.new.cast(options.fetch(:include_optional, false))
    @holiday_dates = normalize_holiday_dates(options[:holiday_dates])
    @client = client || Ibsoft::BusinessCalendar::InvertextoClient.new
  end

  def preview
    { year: year, state_code: state_code, holidays: normalized_holidays }
  end

  def import
    imported = []
    skipped = []

    ApplicationRecord.transaction do
      holidays_for_import.each do |attributes|
        holiday = calendar.holidays.find_or_initialize_by(holiday_date: attributes[:holiday_date])
        if holiday.persisted? && holiday.source == 'manual'
          skipped << holiday.payload
          next
        end

        holiday.assign_attributes(attributes.merge(source: 'invertexto'))
        holiday.save!
        imported << holiday.payload
      end
    end

    { year: year, state_code: state_code, imported: imported, skipped: skipped }
  end

  private

  attr_reader :calendar, :year, :state_code, :include_optional, :holiday_dates, :client

  def normalize_holiday_dates(values)
    return if values.nil?

    Array(values).map { |value| Date.iso8601(value.to_s) }.uniq
  rescue Date::Error
    raise ArgumentError, 'invalid_holiday_date'
  end

  def holidays_for_import
    return normalized_holidays if holiday_dates.nil?

    normalized_holidays.select { |holiday| holiday_dates.include?(holiday[:holiday_date]) }
  end

  def normalized_holidays
    @normalized_holidays ||= begin
      holidays = client.holidays(year: year, state_code: state_code)
      normalized = holidays.filter_map { |item| normalize(item.to_h.stringify_keys) }
      normalized.uniq { |item| item[:holiday_date] }.sort_by { |item| item[:holiday_date] }
    end
  end

  def normalize(item)
    source_scope = source_scope_for(item)
    return if source_scope.blank? || state_without_code?(source_scope)

    holiday_kind = holiday_kind_for(item)
    return if optional_holiday_excluded?(holiday_kind)

    normalized_attributes(item, source_scope, holiday_kind)
  rescue KeyError, Date::Error
    nil
  end

  def source_scope_for(item)
    VALID_LEVELS[item['level'].to_s.downcase]
  end

  def state_without_code?(source_scope)
    source_scope == 'state' && state_code.blank?
  end

  def holiday_kind_for(item)
    item['type'].to_s.downcase == 'feriado' ? 'holiday' : 'optional'
  end

  def optional_holiday_excluded?(holiday_kind)
    holiday_kind == 'optional' && !include_optional
  end

  def normalized_attributes(item, source_scope, holiday_kind)
    {
      holiday_date: Date.iso8601(item.fetch('date')),
      name: item.fetch('name').to_s.squish,
      holiday_kind: holiday_kind,
      source_scope: source_scope,
      state_code: source_scope == 'state' ? state_code : nil
    }
  end
end
