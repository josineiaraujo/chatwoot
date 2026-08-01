require 'rails_helper'

RSpec.describe Ibsoft::MetaTemplates::Catalog do
  let(:account) { create(:account) }
  let(:provider_config) do
    {
      'api_key' => 'token',
      'business_account_id' => 'shared-waba',
      'phone_number_id' => 'phone-id'
    }
  end
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      provider_config: provider_config,
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:client) { instance_double(Ibsoft::MetaTemplates::Client) }
  let(:templates) { [{ 'id' => '1', 'name' => 'aviso' }] }

  it 'uses a fresh existing cache without consulting Meta' do
    allow(client).to receive(:list_templates)
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_columns(
      message_templates: templates,
      message_templates_last_updated: 1.minute.ago
    )
    # rubocop:enable Rails/SkipsModelValidations
    catalog = described_class.new(channel.inbox, client: client)

    expect(catalog.list).to eq(templates)
    expect(client).not_to have_received(:list_templates)
  end

  it 'refreshes every channel in the account that shares the WABA' do
    second_channel = create(
      :channel_whatsapp,
      account: account,
      phone_number: '+15550000002',
      provider: 'whatsapp_cloud',
      provider_config: provider_config.merge('phone_number_id' => 'phone-2'),
      sync_templates: false,
      validate_provider_config: false
    )
    allow(client).to receive(:list_templates).and_return(templates)

    described_class.new(channel.inbox, client: client).refresh!

    expect(channel.reload.message_templates).to eq(templates)
    expect(second_channel.reload.message_templates).to eq(templates)
    expect(second_channel.message_templates_last_updated).to be_present
  end

  it 'does not update a channel from another account with the same WABA' do
    other_account = create(:account)
    other_channel = create(
      :channel_whatsapp,
      account: other_account,
      phone_number: '+15550000003',
      provider: 'whatsapp_cloud',
      provider_config: provider_config,
      sync_templates: false,
      validate_provider_config: false
    )
    original_templates = other_channel.message_templates.deep_dup
    allow(client).to receive(:list_templates).and_return(templates)

    described_class.new(channel.inbox, client: client).refresh!

    expect(other_channel.reload.message_templates).to eq(original_templates)
  end
end
