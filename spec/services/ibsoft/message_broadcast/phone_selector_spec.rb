require 'rails_helper'

RSpec.describe Ibsoft::MessageBroadcast::PhoneSelector do
  subject(:selector) { described_class.new }

  def customer(phone_candidates)
    Ibsoft::Erp::NormalizedCustomer.new(
      external_id: '4797',
      name: 'Cliente teste',
      phone_candidates: phone_candidates
    )
  end

  it 'selects whatsapp as primary and mobile as fallback' do
    selection = selector.call(
      customer(
        [
          { source: 'whatsapp', value: '(75) 98247-9788' },
          { source: 'mobile', value: '(75) 98888-7777' }
        ]
      )
    )

    expect(selection.primary_phone).to eq('+5575982479788')
    expect(selection.fallback_phone).to eq('+5575988887777')
    expect(selection.reason).to eq('primary_and_fallback')
  end

  it 'deduplicates repeated numbers across ERP fields' do
    selection = selector.call(
      customer(
        [
          { source: 'whatsapp', value: '(75) 98247-9788' },
          { source: 'mobile', value: '75982479788' },
          { source: 'landline', value: '(75) 3333-4444' }
        ]
      )
    )

    expect(selection.primary_phone).to eq('+5575982479788')
    expect(selection.fallback_phone).to eq('+557533334444')
  end

  it 'marks customers without valid phones as not deliverable' do
    selection = selector.call(
      customer(
        [
          { source: 'whatsapp', value: 'abc' },
          { source: 'mobile', value: '' }
        ]
      )
    )

    expect(selection).not_to be_deliverable
    expect(selection.reason).to eq('without_valid_phone')
  end
end
