require 'rails_helper'

RSpec.describe Ibsoft::Localization::AccountDefaultTimezone do
  it 'registers every localization extension when its host constant is loaded' do
    aggregate_failures do
      expect(Account).to be < described_class
      expect(Inbox).to be < Ibsoft::Localization::InboxWorkingHourBreaks
      expect(WorkingHour).to be < Ibsoft::Localization::WorkingHourBreakAware
      expect(Api::V1::Accounts::InboxesController).to be < Ibsoft::Localization::InboxesControllerWorkingHourBreaks
    end
  end

  it 'sets the Ibsoft timezone when the account does not define one' do
    account = create(:account)

    expect(account.reporting_timezone).to eq('America/Sao_Paulo')
  end

  it 'preserves an explicitly configured reporting timezone' do
    account = create(:account, reporting_timezone: 'Etc/UTC')

    expect(account.reporting_timezone).to eq('Etc/UTC')
  end

  it 'allows the reporting timezone to be cleared after creation' do
    account = create(:account)

    account.update!(reporting_timezone: nil)

    expect(account.reload.reporting_timezone).to be_nil
  end
end
