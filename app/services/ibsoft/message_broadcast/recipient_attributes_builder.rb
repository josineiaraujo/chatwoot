class Ibsoft::MessageBroadcast::RecipientAttributesBuilder
  def initialize(attributes:)
    @attributes = attributes.with_indifferent_access
  end

  def call
    return if attributes[:external_customer_id].blank?

    {
      external_customer_id: attributes[:external_customer_id],
      customer_name: attributes[:customer_name].presence || attributes[:name],
      primary_phone: primary_phone,
      fallback_phone: fallback_phone,
      template_variable_values: template_variable_values,
      phone_status: phone_status,
      status: deliverable? ? 'pending' : 'skipped',
      error_code: deliverable? ? nil : 'without_valid_phone'
    }
  end

  private

  attr_reader :attributes

  def phone_candidates
    @phone_candidates ||= Ibsoft::MessageBroadcast::RecipientPhoneCandidates.new(
      primary_phone: attributes[:primary_phone],
      fallback_phone: attributes[:fallback_phone]
    ).call
  end

  def primary_phone
    phone_candidates.find { |candidate| candidate.kind == 'primary' }&.phone_number
  end

  def fallback_phone
    phone_candidates.find { |candidate| candidate.kind == 'fallback' }&.phone_number
  end

  def template_variable_values
    values = attributes[:template_variable_values]
    return {} unless values.respond_to?(:to_h)

    values.to_h.transform_values { |value| value.to_s.gsub(/[\r\n]+/, ' ').strip }
  end

  def deliverable?
    primary_phone.present? || fallback_phone.present?
  end

  def phone_status
    return 'primary' if primary_phone.present?
    return 'fallback' if fallback_phone.present?

    'unavailable'
  end
end
