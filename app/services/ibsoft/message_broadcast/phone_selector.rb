class Ibsoft::MessageBroadcast::PhoneSelector
  SOURCE_PRIORITY = %w[whatsapp mobile landline].freeze

  def call(customer)
    normalized_candidates = normalize_candidates(customer.phone_candidates)
    valid_candidates = normalized_candidates.select { |candidate| candidate[:valid] }
    unique_candidates = deduplicate_candidates(valid_candidates)

    Ibsoft::MessageBroadcast::PhoneSelection.new(
      primary_phone: unique_candidates.first&.dig(:phone),
      fallback_phone: unique_candidates.second&.dig(:phone),
      candidates: normalized_candidates,
      reason: selection_reason(unique_candidates)
    )
  end

  private

  def normalize_candidates(candidates)
    normalized_candidates = Array(candidates).map do |candidate|
      normalized_candidate = candidate.with_indifferent_access
      source = normalized_candidate[:source].to_s
      raw_value = normalized_candidate[:value].to_s
      normalized_phone = normalize_phone(raw_value)

      {
        source: source,
        raw_value: raw_value,
        phone: normalized_phone,
        valid: normalized_phone.present?,
        priority: SOURCE_PRIORITY.index(source) || SOURCE_PRIORITY.size
      }
    end

    normalized_candidates.sort_by { |candidate| candidate[:priority] }
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits = "55#{digits}" if digits.length.in?([10, 11])
    return if digits.blank?
    return unless digits.start_with?('55')
    return unless digits.length.in?([12, 13])

    "+#{digits}"
  end

  def deduplicate_candidates(candidates)
    candidates.uniq { |candidate| candidate[:phone] }
  end

  def selection_reason(candidates)
    return 'without_valid_phone' if candidates.empty?
    return 'primary_only' if candidates.one?

    'primary_and_fallback'
  end
end
