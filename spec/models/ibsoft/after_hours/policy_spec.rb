require 'rails_helper'

RSpec.describe Ibsoft::AfterHours::Policy do
  it 'normalizes the exit command before validation' do
    policy = create(:ibsoft_after_hours_policy, exit_command: '  SAIR AGORA  ')

    expect(policy.exit_command).to eq('sair agora')
  end

  it 'requires all customer messages when enabled' do
    policy = build(
      :ibsoft_after_hours_policy,
      enabled: true,
      regular_message: nil,
      holiday_message: nil,
      exit_confirmation_message: nil
    )

    expect(policy).not_to be_valid
    expect(policy.errors.attribute_names).to include(
      :regular_message,
      :holiday_message,
      :exit_confirmation_message
    )
  end

  it 'allows blank customer messages while disabled' do
    policy = build(
      :ibsoft_after_hours_policy,
      enabled: false,
      regular_message: nil,
      holiday_message: nil,
      exit_confirmation_message: nil
    )

    expect(policy).to be_valid
  end

  it 'keeps policy names unique only within the same account' do
    policy = create(:ibsoft_after_hours_policy)

    expect(build(:ibsoft_after_hours_policy, account: policy.account, name: policy.name)).not_to be_valid
    expect(build(:ibsoft_after_hours_policy, name: policy.name)).to be_valid
  end

  it 'rejects multiline or oversized exit commands' do
    multiline = build(:ibsoft_after_hours_policy, exit_command: "sair\nagora")
    oversized = build(:ibsoft_after_hours_policy, exit_command: 'a' * 51)

    expect(multiline).not_to be_valid
    expect(oversized).not_to be_valid
    expect(multiline.errors[:exit_command]).to be_present
    expect(oversized.errors[:exit_command]).to be_present
  end

  it 'does not allow deletion while an active customer wait uses the policy' do
    wait = create(:ibsoft_after_hours_wait)
    policy = wait.after_hours_policy

    expect(policy.destroy).to be(false)
    expect(policy.errors[:base]).to be_present
    expect(described_class.exists?(policy.id)).to be(true)
  end

  it 'allows deletion after all waits are finished' do
    wait = create(:ibsoft_after_hours_wait, status: 'cancelled', finished_at: Time.current)
    policy = wait.after_hours_policy

    expect(policy.destroy).to eq(policy)
    expect(described_class.exists?(policy.id)).to be(false)
  end
end
