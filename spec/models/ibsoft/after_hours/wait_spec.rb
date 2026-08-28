require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::Wait do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:policy) { create(:ibsoft_after_hours_policy, account: account) }
  let(:conversation) { create(:conversation, account: account, team: team) }

  it 'snapshots the exit command and confirmation from the policy' do
    wait = described_class.create!(
      account: account,
      conversation: conversation,
      after_hours_policy: policy,
      team: team,
      cause: 'schedule',
      status: 'active',
      started_at: Time.current
    )

    policy.update!(exit_command: 'cancelar', exit_confirmation_message: 'Nova confirmacao')

    expect(wait.reload).to have_attributes(
      exit_command: 'sair',
      exit_confirmation_message: 'Atendimento encerrado. Voce pode iniciar outro contato quando desejar.'
    )
  end

  it 'requires a unique conversation and valid state values' do
    create(:ibsoft_after_hours_wait, account: account, conversation: conversation, team: team, after_hours_policy: policy)
    duplicate = build(:ibsoft_after_hours_wait, account: account, conversation: conversation, team: team, after_hours_policy: policy)
    invalid = build(
      :ibsoft_after_hours_wait,
      account: account,
      team: team,
      after_hours_policy: policy,
      status: 'unknown',
      cause: 'weekend'
    )

    expect(duplicate).not_to be_valid
    expect(invalid).not_to be_valid
    expect(invalid.errors[:status]).to be_present
    expect(invalid.errors[:cause]).to be_present
  end

  it 'rejects account-scoped associations from another account' do
    other_account = create(:account)
    other_team = create(:team, account: other_account)
    other_policy = create(:ibsoft_after_hours_policy, account: other_account)
    other_conversation = create(:conversation, account: other_account, team: other_team)

    wait = build(
      :ibsoft_after_hours_wait,
      account: account,
      conversation: other_conversation,
      team: other_team,
      after_hours_policy: other_policy
    )

    expect(wait).not_to be_valid
    expect(wait.errors[:conversation]).to be_present
    expect(wait.errors[:team]).to be_present
    expect(wait.errors[:after_hours_policy]).to be_present
  end

  it 'returns only active waits from the active scope' do
    active_wait = create(:ibsoft_after_hours_wait, account: account, team: team, after_hours_policy: policy)
    cancelled_wait = create(:ibsoft_after_hours_wait, status: 'cancelled', finished_at: Time.current)

    expect(described_class.active).to include(active_wait)
    expect(described_class.active).not_to include(cancelled_wait)
  end
end
