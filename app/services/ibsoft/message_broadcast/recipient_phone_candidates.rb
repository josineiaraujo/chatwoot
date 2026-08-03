class Ibsoft::MessageBroadcast::RecipientPhoneCandidates
  Candidate = Data.define(:kind, :phone_number, :source_id)

  def initialize(primary_phone:, fallback_phone:)
    @primary_phone = primary_phone
    @fallback_phone = fallback_phone
  end

  def call
    [candidate('primary', primary_phone), candidate('fallback', fallback_phone)]
      .compact
      .uniq(&:source_id)
  end

  private

  attr_reader :primary_phone, :fallback_phone

  def candidate(kind, value)
    phone_number = normalize(value)
    return if phone_number.blank?

    Candidate.new(kind: kind, phone_number: phone_number, source_id: phone_number.delete_prefix('+'))
  end

  def normalize(value)
    digits = value.to_s.gsub(/\D/, '')
    digits = "55#{digits}" if digits.length.in?([10, 11])
    return unless digits.start_with?('55') && digits.length.in?([12, 13])

    "+#{digits}"
  end
end
