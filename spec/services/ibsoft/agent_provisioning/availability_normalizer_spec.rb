require 'rails_helper'

RSpec.describe Ibsoft::AgentProvisioning::AvailabilityNormalizer do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by!(user: agent) }

  it 'persists the effective offline status when automatic offline is active' do
    account_user.update!(availability: :online, auto_offline: true)

    described_class.new(account_user: account_user).perform

    expect(account_user.reload.availability).to eq('offline')
  end

  it 'keeps the manual status when automatic offline is disabled' do
    account_user.update!(availability: :online, auto_offline: false)

    described_class.new(account_user: account_user).perform

    expect(account_user.reload.availability).to eq('online')
  end
end
