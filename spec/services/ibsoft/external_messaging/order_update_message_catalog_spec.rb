require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog do
  let(:account) { create(:account, locale: 'pt_BR') }
  let(:endpoint) { create(:ibsoft_external_message_endpoint, account: account) }

  it 'provides translated defaults for every supported event' do
    catalog = described_class.new(endpoint: endpoint)

    expect(catalog.defaults.keys).to match_array(described_class::KEYS)
    expect(catalog.defaults['payment_captured']).to include(described_class::PLACEHOLDER)
    expect(catalog.render(key: 'payment_captured', reference_id: '9388')).to include('9388')
  end

  it 'uses the instance override while preserving defaults for other events' do
    endpoint.update!(
      order_update_messages: {
        payment_captured: 'Pagamento {{reference_id}} recebido.'
      }
    )
    catalog = described_class.new(endpoint: endpoint)

    expect(catalog.render(key: 'payment_captured', reference_id: 'ABC-1')).to eq(
      'Pagamento ABC-1 recebido.'
    )
    expect(catalog.effective['order_processing']).to eq(catalog.defaults['order_processing'])
  end
end
