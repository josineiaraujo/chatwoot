class Ibsoft::AgentProvisioning::AvailabilityNormalizer
  attr_reader :account_user

  def initialize(account_user:)
    @account_user = account_user
  end

  def perform
    return account_user if account_user.blank?
    return account_user unless account_user.auto_offline?

    effective_availability = account_user.availability_status
    return account_user if effective_availability == account_user.availability

    account_user.update!(availability: effective_availability)
    account_user
  end
end
