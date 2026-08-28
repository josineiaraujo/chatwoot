require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::InstanceTypeRegistry do
  it 'registers the standard request pipeline as an isolated family' do
    definition = described_class.fetch('standard')

    expect(definition).to have_attributes(
      family: 'standard',
      public_path: '/chathub-sender/',
      order_update_path: '/chathub-sender/pedido/',
      authentication_strategy: 'token',
      username_prefix: nil,
      request_parser_class: Ibsoft::ExternalMessaging::StandardInboundRequestParser,
      request_contract_class: Ibsoft::ExternalMessaging::RequestContract
    )
  end

  it 'registers the SGP generic request pipeline' do
    definition = described_class.fetch('sgp_generic')

    expect(definition).to have_attributes(
      family: 'sgp',
      public_path: '/chathub-sender/sgp/generico/',
      order_update_path: '/chathub-sender/sgp/pedido/',
      authentication_strategy: 'token',
      username_prefix: nil,
      request_parser_class: Ibsoft::ExternalMessaging::InboundRequestParser,
      request_contract_class: Ibsoft::ExternalMessaging::RequestContract
    )
  end

  it 'registers the IXC request pipeline' do
    definition = described_class.fetch('ixc')

    expect(definition).to have_attributes(
      family: 'ixc',
      public_path: '/chathub-sender/ixc/',
      order_update_path: '/chathub-sender/ixc/pedido/',
      authentication_strategy: 'username_password',
      username_prefix: 'ixc',
      request_parser_class: Ibsoft::ExternalMessaging::IxcInboundRequestParser,
      request_contract_class: Ibsoft::ExternalMessaging::RequestContract
    )
  end

  it 'finds the shared contract definition by integration family' do
    expect(described_class.fetch_family('standard')).to eq(described_class.fetch('standard'))
    expect(described_class.fetch_family('sgp')).to eq(described_class.fetch('sgp_generic'))
    expect(described_class.fetch_family('ixc')).to eq(described_class.fetch('ixc'))
  end

  it 'rejects unknown instance types' do
    expect do
      described_class.fetch('unknown')
    end.to raise_error(KeyError)

    expect do
      described_class.fetch_family('unknown')
    end.to raise_error(KeyError)
  end
end
