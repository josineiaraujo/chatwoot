require 'rails_helper'

RSpec.describe Ibsoft::AgentProvisioning::CreateAgent do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:email) { "novo.agente.#{SecureRandom.hex(4)}@example.com" }
  let(:params) { { name: 'Novo Agente', email: email, role: 'agent' } }

  describe '#perform' do
    it 'creates a confirmed native user with a one-time temporary password' do
      result = described_class.new(account: account, inviter: admin, params: params).perform

      user = result.user

      expect(user).to be_confirmed
      expect(user.email).to eq(email)
      expect(user.valid_password?(result.temporary_password)).to be(true)
      expect(user.encrypted_password).not_to include(result.temporary_password)
    end

    it 'creates the native account user link with safe defaults' do
      result = described_class.new(account: account, inviter: admin, params: params).perform

      account_user = account.account_users.find_by!(user: result.user)

      expect(account_user.role).to eq('agent')
      expect(account_user.availability).to eq('offline')
      expect(account_user.auto_offline).to be(true)
      expect(account_user.inviter).to eq(admin)
    end

    it 'allows disabling automatic offline while creating the agent' do
      result = described_class.new(
        account: account,
        inviter: admin,
        params: params.merge(auto_offline: false)
      ).perform

      account_user = account.account_users.find_by!(user: result.user)

      expect(account_user.auto_offline).to be(false)
    end

    it 'can create administrators when explicitly requested' do
      result = described_class.new(
        account: account,
        inviter: admin,
        params: params.merge(role: 'administrator')
      ).perform

      expect(account.account_users.find_by!(user: result.user).role).to eq('administrator')
    end

    it 'links a selected profile and keeps the native role as agent' do
      profile = create(:ibsoft_access_control_role, account: account, name: 'Supervisor')

      result = described_class.new(
        account: account,
        inviter: admin,
        params: params.merge(role: 'administrator', profile_id: profile.id)
      ).perform

      account_user = account.account_users.find_by!(user: result.user)
      assignment = Ibsoft::AccessControl::RoleAssignment.find_by!(account: account, user: result.user)

      expect(account_user.role).to eq('agent')
      expect(assignment.role).to eq(profile)
      expect(assignment.created_by).to eq(admin)
    end

    it 'normalizes email before creating the user' do
      mixed_email = "NOVO.AGENTE.#{SecureRandom.hex(4)}@EXAMPLE.COM"
      result = described_class.new(
        account: account,
        inviter: admin,
        params: params.merge(email: "  #{mixed_email}  ")
      ).perform

      expect(result.user.email).to eq(mixed_email.downcase)
    end

    it 'rejects an existing email because the password cannot be revealed again' do
      existing_user = create(:user)

      expect do
        described_class.new(
          account: account,
          inviter: admin,
          params: params.merge(email: existing_user.email)
        ).perform
      end.to raise_error(described_class::Error, I18n.t('ibsoft.agent_provisioning.errors.email_taken'))
    end

    it 'rejects invalid roles' do
      expect do
        described_class.new(
          account: account,
          inviter: admin,
          params: params.merge(role: 'owner')
        ).perform
      end.to raise_error(described_class::Error, I18n.t('ibsoft.agent_provisioning.errors.invalid_role'))
    end

    it 'rejects profiles from other accounts' do
      other_account = create(:account)
      profile = create(:ibsoft_access_control_role, account: other_account)

      expect do
        described_class.new(
          account: account,
          inviter: admin,
          params: params.merge(profile_id: profile.id)
        ).perform
      end.to raise_error(described_class::Error, I18n.t('ibsoft.agent_provisioning.errors.invalid_profile'))
    end

    it 'respects the account agent limit' do
      allow(account).to receive(:usage_limits).and_return({ agents: account.users.count })

      expect do
        described_class.new(account: account, inviter: admin, params: params).perform
      end.to raise_error(described_class::Error, I18n.t('ibsoft.agent_provisioning.errors.limit_reached'))
    end
  end
end
