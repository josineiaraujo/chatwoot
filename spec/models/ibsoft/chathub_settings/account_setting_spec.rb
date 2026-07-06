require 'rails_helper'

RSpec.describe Ibsoft::ChathubSettings::AccountSetting do
  let(:account) { create(:account) }

  it 'normalizes defaults and custom values' do
    setting = described_class.create!(
      account: account,
      config: {
        agent_entry_assignment: {
          required_percentage: 30,
          ignored_key: true
        }
      }
    )

    expect(setting.effective_config.dig('agent_entry_assignment', 'required_percentage')).to eq(30)
    expect(setting.effective_config['agent_entry_assignment']).not_to include('ignored_key')
    expect(setting.effective_config.dig('login_stabilization', 'enabled')).to be(false)
  end

  it 'rejects invalid percentages and minimums' do
    setting = described_class.new(
      account: account,
      config: {
        agent_entry_assignment: {
          required_percentage: 130,
          minimum_required: 0
        }
      }
    )

    expect(setting).not_to be_valid
    expect(setting.errors[:config].join).to include('required_percentage')
    expect(setting.errors[:config].join).to include('minimum_required')
  end
end
