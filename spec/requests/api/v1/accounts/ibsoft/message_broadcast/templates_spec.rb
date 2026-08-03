require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::MessageBroadcast::Templates', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { { api_access_token: admin.access_token.token } }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:inbox) { channel.inbox }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/message_broadcast/templates" }
  let(:standard_template) do
    {
      id: 'template_1',
      name: 'aviso_manutencao',
      language: 'pt_BR',
      status: 'APPROVED',
      category: 'UTILITY',
      parameter_format: 'POSITIONAL',
      components: [
        { type: 'HEADER', format: 'TEXT', text: 'Olá {{1}}' },
        { type: 'BODY', text: 'Cliente {{1}}, seu plano {{2}} terá manutenção.' },
        { type: 'FOOTER', text: 'Equipe de atendimento' },
        {
          type: 'BUTTONS',
          buttons: [
            { type: 'QUICK_REPLY', text: 'Falar com atendimento' },
            { type: 'URL', text: 'Abrir fatura', url: 'https://example.com/{{2}}' },
            { type: 'COPY_CODE', text: 'Copiar código', example: ['DESCONTO10'] },
            { type: 'PHONE_NUMBER', text: 'Ligar', phone_number: '+5511999999999' }
          ]
        }
      ]
    }
  end
  let(:media_template) do
    {
      id: 'template_media',
      name: 'boleto_com_documento',
      language: 'pt_BR',
      status: 'APPROVED',
      category: 'UTILITY',
      parameter_format: 'POSITIONAL',
      components: [
        { type: 'HEADER', format: 'DOCUMENT', example: { header_handle: ['document-handle'] } },
        { type: 'BODY', text: 'Segue o documento solicitado.' }
      ]
    }
  end
  let(:order_templates) do
    [
      {
        id: 'order_details_display_format', name: 'detalhes_do_pedido', language: 'pt_BR',
        status: 'APPROVED', category: 'UTILITY', display_format: 'ORDER_DETAILS', components: []
      },
      {
        id: 'order_details_button', name: 'pagamento_do_pedido', language: 'pt_BR',
        status: 'APPROVED', category: 'UTILITY',
        components: [{ type: 'BUTTONS', buttons: [{ type: 'ORDER_DETAILS', text: 'Ver pedido' }] }]
      },
      {
        id: 'order_status', name: 'status_do_pedido', language: 'pt_BR',
        status: 'APPROVED', category: 'UTILITY', sub_category: 'ORDER_STATUS', components: []
      }
    ]
  end

  def expect_standard_template(template)
    expect(template).to include(
      'id' => 'template_1', 'name' => 'aviso_manutencao', 'language' => 'pt_BR',
      'status' => 'APPROVED', 'category' => 'UTILITY', 'parameter_format' => 'POSITIONAL'
    )
    expect(template['components']).to include(
      include('type' => 'BODY', 'text' => 'Cliente {{1}}, seu plano {{2}} terá manutenção.')
    )
    expect(template.dig('components', 3, 'buttons')).to include(
      include('type' => 'COPY_CODE', 'example' => ['DESCONTO10'])
    )
  end

  def expect_standard_variables(variables)
    expect(variables).to contain_exactly(
      variable_matcher('header:1', '1', 'HEADER'),
      variable_matcher('body:1', '1', 'BODY'),
      variable_matcher('body:2', '2', 'BODY'),
      variable_matcher(
        'buttons:1:2', '2', 'BUTTONS',
        'button_type' => 'url', 'button_index' => 1, 'button_text' => 'Abrir fatura'
      ),
      variable_matcher(
        'buttons:2:copy_code', 'copy_code', 'BUTTONS',
        'button_type' => 'copy_code', 'button_index' => 2, 'button_text' => 'Copiar código'
      )
    )
  end

  def variable_matcher(key, parameter_key, component_type, attributes = {})
    include(
      {
        'key' => key, 'parameter_key' => parameter_key, 'label' => "{{#{parameter_key}}}",
        'component_type' => component_type, 'parameter_type' => 'text'
      }.merge(attributes)
    )
  end

  def expect_media_template(template)
    expect(template['variables']).to contain_exactly(
      include(
        'key' => 'header_media_url', 'parameter_key' => 'media_url',
        'component_type' => 'HEADER', 'parameter_type' => 'media', 'media_type' => 'document'
      )
    )
  end

  it 'syncs templates from Meta and returns normalized components and variables' do
    request = stub_request(:get, 'https://graph.facebook.com/v14.0/123456789/message_templates?access_token=test_key')
              .to_return(
                status: 200,
                body: {
                  data: [standard_template, media_template, *order_templates]
                }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    get base_url, params: { inbox_id: inbox.id }, headers: headers, as: :json

    templates = response.parsed_body['templates']
    aggregate_failures do
      expect(response).to have_http_status(:success)
      expect(request).to have_been_requested.at_least_once
      expect_standard_template(templates.first)
      expect_standard_variables(templates.first['variables'])
      expect_media_template(templates.second)
      expect(templates.pluck('id')).to eq(%w[template_1 template_media])
    end
  end

  it 'does not request runtime values for static template buttons' do
    static_template = standard_template.deep_dup
    static_template[:components].last[:buttons] = [
      { type: 'QUICK_REPLY', text: 'Confirmar' },
      { type: 'URL', text: 'Abrir site', url: 'https://example.com' },
      { type: 'PHONE_NUMBER', text: 'Ligar', phone_number: '+5511999999999' }
    ]
    stub_request(:get, 'https://graph.facebook.com/v14.0/123456789/message_templates?access_token=test_key')
      .to_return(status: 200, body: { data: [static_template] }.to_json, headers: { 'Content-Type' => 'application/json' })

    get base_url, params: { inbox_id: inbox.id }, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('templates', 0, 'variables')).to contain_exactly(
      include('key' => 'header:1', 'component_type' => 'HEADER'),
      include('key' => 'body:1', 'component_type' => 'BODY'),
      include('key' => '2', 'component_type' => 'BODY')
    )
  end

  it 'rejects non-WhatsApp inboxes' do
    widget_inbox = create(:inbox, account: account)

    get base_url, params: { inbox_id: widget_inbox.id }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to eq('unsupported_whatsapp_inbox')
  end
end
