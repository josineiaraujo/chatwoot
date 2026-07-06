require 'rails_helper'

RSpec.describe Ibsoft::AgentProvisioning::ResetTemporaryPassword do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }

  describe '#perform' do
    it 'updates the user password and returns the generated password once' do
      previous_encrypted_password = agent.encrypted_password

      result = described_class.new(account: account, user: agent).perform

      expect(result.temporary_password).to be_present
      expect(agent.reload.encrypted_password).not_to eq(previous_encrypted_password)
      expect(agent.valid_password?(result.temporary_password)).to be(true)
      expect(agent.encrypted_password).not_to include(result.temporary_password)
    end

    it 'rejects users authenticated by an external provider' do
      agent.update!(provider: 'saml')

      expect do
        described_class.new(account: account, user: agent).perform
      end.to raise_error(described_class::Error, I18n.t('ibsoft.agent_provisioning.errors.external_provider'))
    end
  end
end
