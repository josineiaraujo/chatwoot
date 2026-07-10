require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Templates', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:inbox) { channel.inbox }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/templates" }

  it 'syncs templates from Meta and returns normalized components and variables' do
    request = stub_request(:get, 'https://graph.facebook.com/v14.0/123456789/message_templates?access_token=test_key')
              .to_return(
                status: 200,
                body: {
                  data: [
                    {
                      id: 'template_1',
                      name: 'aviso_manutencao',
                      language: 'pt_BR',
                      status: 'APPROVED',
                      category: 'UTILITY',
                      components: [
                        { type: 'HEADER', format: 'TEXT', text: 'Olá {{1}}' },
                        { type: 'BODY', text: 'Cliente {{1}}, seu plano {{2}} terá manutenção.' },
                        { type: 'FOOTER', text: 'Equipe de atendimento' },
                        {
                          type: 'BUTTONS',
                          buttons: [
                            { type: 'URL', text: 'Abrir', url: 'https://example.com/{{2}}' }
                          ]
                        }
                      ]
                    }
                  ]
                }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    get base_url, params: { inbox_id: inbox.id }, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(request).to have_been_requested.at_least_once
    expect(response.parsed_body['templates'].first).to include(
      'id' => 'template_1',
      'name' => 'aviso_manutencao',
      'language' => 'pt_BR',
      'status' => 'APPROVED',
      'category' => 'UTILITY'
    )
    expect(response.parsed_body['templates'].first['components']).to include(
      include('type' => 'BODY', 'text' => 'Cliente {{1}}, seu plano {{2}} terá manutenção.')
    )
    expect(response.parsed_body['templates'].first['variables']).to contain_exactly(
      include('key' => '1', 'label' => '{{1}}', 'component_type' => 'HEADER'),
      include('key' => '2', 'label' => '{{2}}', 'component_type' => 'BODY')
    )
  end

  it 'rejects non-WhatsApp inboxes' do
    widget_inbox = create(:inbox, account: account)

    get base_url, params: { inbox_id: widget_inbox.id }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('unsupported_whatsapp_inbox')
  end
end
