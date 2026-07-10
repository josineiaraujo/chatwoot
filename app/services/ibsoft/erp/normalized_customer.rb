class Ibsoft::Erp::NormalizedCustomer
  ATTRIBUTES = %i[
    external_id name document active city_id city_name state_id state zip_code
    address neighborhood phone_candidates contract_ids plan_ids source
  ].freeze
  STRING_ATTRIBUTES = %i[
    external_id name document city_id city_name state_id state zip_code address
    neighborhood source
  ].freeze

  attr_reader(*ATTRIBUTES)

  def initialize(attributes = {})
    @normalized_attributes = attributes.with_indifferent_access

    assign_string_attributes
    @active = ActiveModel::Type::Boolean.new.cast(normalized_attributes[:active])
    @phone_candidates = normalize_phone_candidates(normalized_attributes[:phone_candidates])
    @contract_ids = normalize_array(normalized_attributes[:contract_ids])
    @plan_ids = normalize_array(normalized_attributes[:plan_ids])
  end

  def payload
    ATTRIBUTES.index_with { |attribute| public_send(attribute) }
  end

  private

  attr_reader :normalized_attributes

  def assign_string_attributes
    STRING_ATTRIBUTES.each do |attribute|
      instance_variable_set("@#{attribute}", normalized_attributes[attribute].to_s)
    end
  end

  def normalize_phone_candidates(candidates)
    Array(candidates).filter_map do |candidate|
      next if candidate.blank?

      normalized_candidate = candidate.with_indifferent_access
      value = normalized_candidate[:value].to_s.strip
      next if value.blank?

      {
        source: normalized_candidate[:source].to_s,
        value: value
      }
    end
  end

  def normalize_array(value)
    Array(value).compact_blank.map(&:to_s).uniq
  end
end
