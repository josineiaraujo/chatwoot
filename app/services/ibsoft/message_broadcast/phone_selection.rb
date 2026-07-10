class Ibsoft::MessageBroadcast::PhoneSelection
  attr_reader :primary_phone, :fallback_phone, :candidates, :reason

  def initialize(primary_phone:, fallback_phone:, candidates:, reason:)
    @primary_phone = primary_phone
    @fallback_phone = fallback_phone
    @candidates = candidates
    @reason = reason
  end

  def deliverable?
    primary_phone.present? || fallback_phone.present?
  end

  def payload
    {
      primary_phone: primary_phone,
      fallback_phone: fallback_phone,
      candidates: candidates,
      deliverable: deliverable?,
      reason: reason
    }
  end
end
