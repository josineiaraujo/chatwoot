class Ibsoft::Erp::Adapters::Ixc::QueryBuilder
  def self.payload(**options)
    new(options).payload
  end

  def initialize(options)
    @options = options.with_indifferent_access
  end

  def payload
    payload = {
      qtype: "#{table}.#{field}",
      query: query.to_s,
      oper: operator.to_s,
      page: page.to_s,
      rp: per_page.to_s,
      sortname: sort_field.presence || "#{table}.id",
      sortorder: sort_order.to_s
    }

    normalized_filters = normalize_filters(filters)
    payload[:grid_param] = normalized_filters.to_json if normalized_filters.present?
    payload
  end

  private

  attr_reader :options

  def table
    options[:table]
  end

  def field
    options[:field]
  end

  def query
    options[:query]
  end

  def operator
    options[:operator]
  end

  def page
    options[:page].presence || 1
  end

  def per_page
    options[:per_page].presence || 50
  end

  def sort_field
    options[:sort_field].presence || "#{table}.id"
  end

  def sort_order
    options[:sort_order].presence || 'asc'
  end

  def filters
    options[:filters]
  end

  def normalize_filters(filters)
    Array(filters).filter_map do |filter|
      normalized_filter = filter.with_indifferent_access
      field = normalized_filter[:field].to_s
      operator = normalized_filter[:operator].to_s
      value = normalized_filter[:value].to_s
      next if field.blank? || operator.blank? || value.blank?

      {
        TB: field,
        OP: operator,
        P: value
      }
    end
  end
end
