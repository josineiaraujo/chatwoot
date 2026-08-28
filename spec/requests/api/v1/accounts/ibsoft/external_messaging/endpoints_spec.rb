require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::ExternalMessaging::Endpoints', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/external_messaging/endpoints" }

  def order_update_template_descriptor(id:, name:, parameter_format: 'POSITIONAL', body_parameter: nil)
    {
      'id' => id,
      'name' => name,
      'language' => 'pt_BR',
      'parameter_format' => parameter_format,
      'body_parameter' => body_parameter
    }
  end

  def stub_order_update_template_catalog(endpoint, templates)
    catalog = instance_double(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog)
    templates.each { |id, template| allow(catalog).to receive(:find).with(id).and_return(template) }
    allow(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog).to receive(:new)
      .with(endpoint: endpoint)
      .and_return(catalog)
  end

  it 'allows an administrator to create and list an endpoint without exposing its digest' do
    post base_url,
         params: {
           name: 'ERP principal',
           inbox_id: channel.inbox.id,
           instance_type: 'sgp_generic',
           rate_limit_per_second: 15
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:created)
    token = response.parsed_body['token']
    expect(token).to start_with('ibext_')
    created_endpoint = Ibsoft::ExternalMessaging::Endpoint.find(response.parsed_body['id'])
    token_digest = created_endpoint.token_digest
    create_list(:ibsoft_external_message_delivery, 2, endpoint: created_endpoint)

    get base_url, headers: admin_headers, as: :json

    endpoint = response.parsed_body['endpoints'].first
    expect(endpoint).to include(
      'name' => 'ERP principal',
      'inbox_id' => channel.inbox.id,
      'instance_type' => 'sgp_generic',
      'integration_family' => 'sgp',
      'public_path' => '/chathub-sender/sgp/generico/',
      'order_update_path' => '/chathub-sender/sgp/pedido/',
      'rate_limit_per_second' => 15,
      'allow_order_resends' => true,
      'failure_diagnostics_enabled' => false,
      'deliveries_count' => 2
    )
    expect(endpoint).not_to have_key('token')
    expect(endpoint).not_to have_key('token_digest')
    expect(created_endpoint.reload.token_digest).to eq(token_digest)
    expect(Ibsoft::ExternalMessaging::Endpoint.authenticate(token)).to eq(created_endpoint)
  end

  it 'creates the standard contract with isolated paths and bearer authentication' do
    post base_url,
         params: {
           name: 'API padrão',
           inbox_id: channel.inbox.id,
           instance_type: 'standard'
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'instance_type' => 'standard',
      'integration_family' => 'standard',
      'public_path' => '/chathub-sender/',
      'order_update_path' => '/chathub-sender/pedido/'
    )
    expect(response.parsed_body.fetch('token')).to start_with('ibext_')
    expect(response.parsed_body.fetch('authentication')).to include('type' => 'token')
  end

  it 'allows administrators to disable order resends for an instance' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )

    patch "#{base_url}/#{endpoint.id}",
          params: { allow_order_resends: false },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(endpoint.reload.allow_order_resends).to be(false)
    expect(response.parsed_body['allow_order_resends']).to be(false)
  end

  it 'allows administrators to enable detailed failure diagnostics for an instance' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )

    patch "#{base_url}/#{endpoint.id}",
          params: { failure_diagnostics_enabled: true },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(endpoint.reload.failure_diagnostics_enabled).to be(true)
    expect(response.parsed_body['failure_diagnostics_enabled']).to be(true)
  end

  it 'does not allow changing the instance type after creation' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )

    patch "#{base_url}/#{endpoint.id}",
          params: { instance_type: 'unknown', name: 'Novo nome' },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(endpoint.reload).to have_attributes(
      name: 'Novo nome',
      instance_type: 'sgp_generic'
    )
  end

  it 'blocks non-administrators' do
    get base_url, headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rotates a token and invalidates the previous one' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )
    old_token = endpoint.rotate_token!

    post "#{base_url}/#{endpoint.id}/rotate_token",
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['token']).not_to eq(old_token)
    expect(Ibsoft::ExternalMessaging::Endpoint.authenticate(old_token)).to be_nil
  end

  it 'creates IXC credentials once and lists only safe authentication metadata', :aggregate_failures do
    post base_url,
         params: {
           name: 'IXC principal',
           inbox_id: channel.inbox.id,
           instance_type: 'ixc',
           rate_limit_per_second: 10
         },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:created)
    credentials = response.parsed_body.fetch('credentials')
    endpoint_id = response.parsed_body.fetch('id')
    expect(credentials).to include(
      'type' => 'username_password',
      'username' => "ixc_#{endpoint_id}"
    )
    expect(credentials.fetch('password')).to start_with('ibext_')
    expect(response.parsed_body).not_to have_key('token')

    get base_url, headers: admin_headers, as: :json

    listed = response.parsed_body.fetch('endpoints').find { |item| item['id'] == endpoint_id }
    expect(listed).to include(
      'integration_family' => 'ixc',
      'public_path' => '/chathub-sender/ixc/',
      'order_update_path' => '/chathub-sender/ixc/pedido/'
    )
    expect(listed.fetch('authentication')).to include(
      'type' => 'username_password',
      'username' => "ixc_#{endpoint_id}"
    )
    expect(listed.fetch('authentication')).not_to have_key('password')
    expect(listed.to_json).not_to include(credentials.fetch('password'))
  end

  it 'rotates only the IXC password while preserving the generated username' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel,
      instance_type: 'ixc'
    )
    old_password = endpoint.rotate_token!

    post "#{base_url}/#{endpoint.id}/rotate_token",
         headers: admin_headers,
         as: :json

    credentials = response.parsed_body.fetch('credentials')
    expect(credentials.fetch('username')).to eq("ixc_#{endpoint.id}")
    expect(credentials.fetch('password')).not_to eq(old_password)
    expect(Ibsoft::ExternalMessaging::Endpoint.authenticate(old_password)).to be_nil
  end

  it 'updates order defaults without exposing the key and preserves it when omitted', :aggregate_failures do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )

    patch "#{base_url}/#{endpoint.id}",
          params: {
            order_defaults: {
              merchant_name: 'IBSoft Cloud',
              key: '12345678000199',
              key_type: 'cnpj',
              messages: {
                payment_captured: 'Pagamento {{reference_id}} confirmado.'
              }
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('12345678000199')
    expect(response.parsed_body).to include('order_defaults_configured' => true)
    expect(response.parsed_body['order_defaults']).to include(
      'merchant_name' => 'IBSoft Cloud',
      'key_type' => 'CNPJ',
      'key_configured' => true,
      'key_hint' => '****0199',
      'messages' => hash_including(
        'payment_captured' => 'Pagamento {{reference_id}} confirmado.'
      ),
      'message_defaults' => hash_including('payment_captured')
    )
    expect(endpoint.reload.order_update_messages).to eq(
      'payment_captured' => 'Pagamento {{reference_id}} confirmado.'
    )

    patch "#{base_url}/#{endpoint.id}",
          params: { order_defaults: { merchant_name: 'Novo nome', key_type: 'CNPJ' } },
          headers: admin_headers,
          as: :json

    expect(endpoint.reload).to have_attributes(
      order_pix_merchant_name: 'Novo nome',
      order_pix_key: '12345678000199'
    )
  end

  it 'allows explicitly removing a configured PIX key' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel,
      order_pix_merchant_name: 'IBSoft Cloud',
      order_pix_key: '12345678000199',
      order_pix_key_type: 'CNPJ'
    )

    patch "#{base_url}/#{endpoint.id}",
          params: { order_defaults: { clear_key: true } },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(endpoint.reload.order_pix_key).to be_nil
    expect(response.parsed_body['order_defaults_configured']).to be(false)
  end

  it 'lists only compatible order-update templates for the endpoint channel' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )
    templates = [
      {
        'id' => 'template-1',
        'name' => 'atualizacao_fatura',
        'language' => 'pt_BR',
        'parameter_format' => 'NAMED',
        'body_parameter' => {
          'format' => 'named',
          'key' => 'mensagem_status'
        }
      }
    ]
    catalog = instance_double(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog, list: templates)
    allow(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog).to receive(:new)
      .with(endpoint: endpoint)
      .and_return(catalog)

    get "#{base_url}/#{endpoint.id}/order_update_templates",
        headers: admin_headers,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('templates' => templates)
  end

  it 'stores the default template and optional event overrides without exposing raw template data' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )
    default_template = order_update_template_descriptor(
      id: 'default-1',
      name: 'atualizacao_padrao',
      parameter_format: 'NAMED',
      body_parameter: { 'format' => 'named', 'key' => 'mensagem_status' }
    )
    paid_template = order_update_template_descriptor(id: 'paid-1', name: 'pagamento_confirmado')
    stub_order_update_template_catalog(
      endpoint,
      'default-1' => default_template,
      'paid-1' => paid_template
    )

    patch "#{base_url}/#{endpoint.id}",
          params: {
            order_defaults: {
              update_delivery: {
                mode: 'template',
                default_template_id: 'default-1',
                overrides: { payment_captured: 'paid-1' }
              }
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(endpoint.reload).to have_attributes(order_update_delivery_mode: 'template')
    expect(endpoint.order_update_template_settings).to eq(
      'default' => default_template,
      'overrides' => { 'payment_captured' => paid_template }
    )
    expect(response.parsed_body['order_update_template_ready']).to be(true)
    expect(response.parsed_body.dig('order_defaults', 'update_delivery')).to include(
      'mode' => 'template',
      'template_ready' => true,
      'default_template' => default_template,
      'overrides' => { 'payment_captured' => paid_template }
    )
  end

  it 'rejects template delivery when the selected template is not compatible' do
    endpoint = create(
      :ibsoft_external_message_endpoint,
      account: account,
      created_by: admin,
      whatsapp_channel: channel
    )
    catalog = instance_double(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog)
    allow(catalog).to receive(:find).with('invalid-template').and_return(nil)
    allow(Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog).to receive(:new)
      .with(endpoint: endpoint)
      .and_return(catalog)

    patch "#{base_url}/#{endpoint.id}",
          params: {
            order_defaults: {
              update_delivery: {
                mode: 'template',
                default_template_id: 'invalid-template'
              }
            }
          },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('order_update_template_invalid')
    expect(endpoint.reload.order_update_delivery_mode).to eq('interactive')
  end

  it 'keeps the template catalog isolated by account' do
    foreign_endpoint = create(:ibsoft_external_message_endpoint)

    get "#{base_url}/#{foreign_endpoint.id}/order_update_templates",
        headers: admin_headers,
        as: :json

    expect(response).to have_http_status(:not_found)
  end
end
