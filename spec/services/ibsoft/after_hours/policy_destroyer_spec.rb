require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::PolicyDestroyer do
  it 'rolls back detached distribution policies when an active wait prevents deletion' do
    wait = create(:ibsoft_after_hours_wait)
    policy = wait.after_hours_policy
    distribution_policy = create(
      :ibsoft_distribution_policy,
      account: policy.account,
      after_hours_policy: policy,
      config: {
        unavailability: {
          outside_business_hours: { action: 'after_hours_policy' }
        }
      }
    )

    result = described_class.new(policy: policy).perform

    expect(result).to be(false)
    expect(policy.reload).to be_present
    expect(distribution_policy.reload.after_hours_policy_id).to eq(policy.id)
    expect(distribution_policy.config.dig('unavailability', 'outside_business_hours', 'action')).to eq(
      'after_hours_policy'
    )
  end
end
