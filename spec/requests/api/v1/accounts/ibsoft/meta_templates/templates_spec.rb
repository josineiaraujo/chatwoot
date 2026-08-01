require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MetaTemplates::Templates', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:provider_config) do
    {
      'api_key' => 'secret-token',
      'business_account_id' => 'waba-123',
      'phone_number_id' => 'phone-123'
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
  let(:inbox) { channel.inbox }
  let(:base_url) do
    "/api/v1/accounts/#{account.id}/ibsoft/meta_templates/inboxes/#{inbox.id}/templates"
  end
  let(:meta_templates) do
    [
      {
        id: 'template-2',
        name: 'promocao',
        language: 'pt_BR',
        category: 'MARKETING',
        status: 'PENDING',
        last_updated_time: '2026-07-29T13:00:00+0000',
        components: [{ type: 'BODY', text: 'Oferta' }]
      },
      {
        id: 'template-1',
        name: 'aviso',
        language: 'pt_BR',
        category: 'UTILITY',
        status: 'APPROVED',
        last_updated_time: '2026-07-28T13:00:00+0000',
        components: [{ type: 'BODY', text: 'Aviso' }]
      }
    ]
  end

  before do
    # The native factory seeds credentials and a fresh template catalog.
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_column(:provider_config, provider_config)
    channel.update_column(:message_templates_last_updated, nil)
    # rubocop:enable Rails/SkipsModelValidations
    allow(GlobalConfigService).to receive(:load)
      .with('WHATSAPP_API_VERSION', 'v22.0')
      .and_return('v22.0')
  end

  def stub_catalog(data = meta_templates)
    stub_request(
      :get,
      %r{https://graph\.facebook\.com/v22\.0/waba-123/message_templates}
    ).to_return(
      status: 200,
      body: { data: data }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def stub_order_details_creation
    stub_request(
      :post,
      'https://graph.facebook.com/v22.0/waba-123/message_templates'
    ).with { |request| order_details_payload?(request) }.to_return(
      status: 200,
      body: { id: 'template-order', status: 'PENDING' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def order_details_payload?(request)
    payload = JSON.parse(request.body)
    expected_button = [
      { 'type' => 'ORDER_DETAILS', 'text' => 'Copy Pix code' }
    ]
    has_order_button = payload['components'].any? do |component|
      component['buttons'] == expected_button
    end
    has_header = payload['components'].any? do |component|
      component['type'] == 'HEADER'
    end

    payload['category'] == 'UTILITY' &&
      payload['display_format'] == 'ORDER_DETAILS' &&
      has_order_button &&
      !has_header &&
      !payload.keys.intersect?(%w[model special])
  end

  def order_details_catalog_entry
    {
      id: 'template-order',
      name: 'detalhes_fatura',
      language: 'pt_BR',
      category: 'UTILITY',
      status: 'PENDING',
      display_format: 'ORDER_DETAILS',
      components: [
        { type: 'BODY', text: 'Confira sua fatura' },
        {
          type: 'BUTTONS',
          buttons: [{ type: 'ORDER_DETAILS', text: 'Copy Pix code' }]
        }
      ]
    }
  end

  def order_details_attributes
    {
      name: 'detalhes_fatura',
      language: 'pt_BR',
      category: 'UTILITY',
      model: 'order_details',
      parameter_format: 'named',
      header: {
        format: 'NONE',
        text: '',
        examples: {}
      },
      body: { text: 'Confira sua fatura', examples: {} },
      footer: { text: '' },
      buttons: []
    }
  end

  it 'lists, filters and paginates templates without exposing channel credentials' do
    stub_catalog

    get base_url,
        params: { category: 'UTILITY', page: 1, per_page: 10 },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['templates'].pluck('id')).to eq(['template-1'])
    expect(response.parsed_body['meta']).to include(
      'page' => 1,
      'per_page' => 10,
      'total' => 1
    )
    expect(response.parsed_body['context']).to include(
      'inbox_id' => inbox.id,
      'business_account_id' => 'waba-123'
    )
    expect(response.body).not_to include('secret-token')
  end

  it 'orders the most recently changed templates first and leaves undated templates last' do
    stub_catalog(
      [
        meta_templates.second,
        meta_templates.first,
        {
          id: 'template-undated',
          name: 'antigo_sem_data',
          language: 'pt_BR',
          category: 'UTILITY',
          status: 'APPROVED',
          components: [{ type: 'BODY', text: 'Sem data' }]
        }
      ]
    )

    get base_url,
        params: { page: 1, per_page: 10 },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['templates'].pluck('id')).to eq(
      %w[template-2 template-1 template-undated]
    )
    expect(response.parsed_body.dig('templates', 0, 'last_updated_time')).to eq(
      '2026-07-29T13:00:00+0000'
    )
  end

  it 'defaults to 30 templates per page after sorting the complete catalog' do
    catalog = Array.new(31) do |index|
      {
        id: "template-#{index}",
        name: "modelo_#{index}",
        language: 'pt_BR',
        category: 'UTILITY',
        status: 'APPROVED',
        last_updated_time: (Time.zone.local(2026, 7, 1) + index.days).iso8601,
        components: [{ type: 'BODY', text: "Modelo #{index}" }]
      }
    end
    stub_catalog(catalog.rotate(11))

    get base_url,
        params: { page: 1 },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['meta']).to include(
      'page' => 1,
      'per_page' => 30,
      'total' => 31,
      'total_pages' => 2
    )
    expect(response.parsed_body['templates'].pluck('id')).to eq(
      (1..30).to_a.reverse.map { |index| "template-#{index}" }
    )

    get base_url,
        params: { page: 2 },
        headers: headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['templates'].pluck('id')).to eq(['template-0'])
  end

  it 'creates a template and refreshes the catalog' do
    create_request = stub_request(
      :post,
      'https://graph.facebook.com/v22.0/waba-123/message_templates'
    ).to_return(
      status: 200,
      body: { id: 'template-new', status: 'PENDING' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_catalog(
      [
        {
          id: 'template-new',
          name: 'novo_aviso',
          language: 'pt_BR',
          category: 'UTILITY',
          status: 'PENDING',
          components: [{ type: 'BODY', text: 'Olá {{nome}}' }]
        }
      ]
    )

    post base_url,
         params: {
           template: {
             name: 'novo_aviso',
             language: 'pt_BR',
             category: 'UTILITY',
             model: 'standard',
             parameter_format: 'named',
             header: { format: 'NONE', text: '', examples: {} },
             body: {
               text: 'Olá {{nome}}',
               examples: { nome: 'Maria' }
             },
             footer: { text: '' },
             buttons: []
           }
         },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('template', 'id')).to eq('template-new')
    expect(create_request).to have_been_requested.once
  end

  it 'forwards special template contracts without exposing internal model fields' do
    create_request = stub_order_details_creation
    stub_catalog([order_details_catalog_entry])

    post base_url,
         params: { template: order_details_attributes },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(create_request).to have_been_requested.once
  end

  it 'returns structured validation errors before calling Meta' do
    post base_url,
         params: {
           template: {
             name: 'Invalid Name',
             category: 'UTILITY',
             model: 'standard',
             body: { text: '' }
           }
         },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('validation_failed')
    expect(response.parsed_body['details']).to include(
      include('field' => 'name'),
      include('field' => 'body')
    )
    expect(a_request(:any, /graph\.facebook\.com/)).not_to have_been_made
  end

  it 'rejects agents and preserves account isolation' do
    get base_url,
        headers: { api_access_token: agent.access_token.token },
        as: :json
    expect(response).to have_http_status(:unauthorized)

    other_account = create(:account)
    other_channel = create(
      :channel_whatsapp,
      account: other_account,
      phone_number: '+15550000004',
      provider: 'whatsapp_cloud',
      provider_config: provider_config,
      sync_templates: false,
      validate_provider_config: false
    )
    isolated_url = "/api/v1/accounts/#{account.id}/ibsoft/meta_templates/inboxes/#{other_channel.inbox.id}/templates"

    get isolated_url, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'rejects non-WhatsApp Cloud channels' do
    widget_inbox = create(:inbox, account: account)
    unsupported_url = "/api/v1/accounts/#{account.id}/ibsoft/meta_templates/inboxes/#{widget_inbox.id}/templates"

    get unsupported_url, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('unsupported_channel')
  end
end
