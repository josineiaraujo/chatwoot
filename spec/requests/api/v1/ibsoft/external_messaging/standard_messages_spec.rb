require 'rails_helper'

RSpec.describe 'Ibsoft external messaging standard endpoint', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:raw_token) { "ibext_#{SecureRandom.urlsafe_base64(32)}" }
  let(:endpoint) do
    create(
      :ibsoft_external_message_endpoint,
      account: account,
      inbox: channel.inbox,
      created_by: admin,
      instance_type: 'standard',
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(raw_token)
    )
  end
  let(:url) { '/chathub-sender/' }
  let(:headers) do
    {
      'Authorization' => "Bearer #{raw_token}",
      'Content-Type' => 'text/plain; charset=UTF-8'
    }
  end
  let(:simple_payload) do
    [
      '[template_name]=ticket_status_updated',
      '[template_language]=en',
      '[to]=+55 (75) 98247-9788',
      '[tipo-canal]=whatsapp-cloud',
      '[body.name]=Cliente Teste',
      '[body.ticket_id]=42'
    ].join('||')
  end
  let(:order_payload) do
    [
      '[template_name]=lembrete_fatura_pdf_pix',
      '[template_type]=order',
      '[to]=5575982479788',
      '[tipo-canal]=whatsapp-cloud',
      '[header_type]=document',
      '[header_link]=https://sistema.example/boleto/9388.pdf',
      '[header_append_pdf]=false',
      '[body.nome_cliente]=José Augusto Silva',
      '[body.vencimento_fatura]=10/08/2027',
      '[order.reference_id]=standard-9388',
      '[order.total]=64,99',
      '[order.item_name]=Fatura de internet',
      '[order.payment.pix.code]=PIX_COPIA_E_COLA',
      '[order.payment.pix.merchant_name]=IBSoft Cloud',
      '[order.payment.pix.key]=12345678000199',
      '[order.payment.pix.key_type]=CNPJ',
      '[order.payment.boleto.digitable_line]=00190000090350182490218767625173516510000006499'
    ].join('||')
  end

  before { endpoint }

  it 'accepts the exact POST contract and only queues the normalized message', :aggregate_failures do
    expect do
      post url, params: simple_payload, headers: headers
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
                                                              .and have_enqueued_job(
                                                                Ibsoft::ExternalMessaging::SendDeliveryJob
                                                              )
      .and not_change(Contact, :count)
      .and not_change(Conversation, :count)
      .and not_change(Message, :count)

    expect(response).to have_http_status(:accepted)
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(response.headers['Pragma']).to eq('no-cache')
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(response.parsed_body).to include(
      'ok' => true,
      'status' => 'accepted',
      'message_id' => nil,
      'template_name' => 'ticket_status_updated',
      'template_type' => 'simple'
    )

    delivery = Ibsoft::ExternalMessaging::Delivery.last
    expect(delivery).to have_attributes(
      endpoint_id: endpoint.id,
      account_id: account.id,
      inbox_id: channel.inbox.id,
      recipient: '5575982479788',
      status: 'queued'
    )
    expect(delivery.template_components.to_json).not_to include(raw_token, 'tipo-canal', '"to"')
    expect(delivery.attributes).not_to include('payload', 'raw_payload', 'request_body')
  end

  it 'processes an order through the existing durable order pipeline' do
    expect do
      post url, params: order_payload, headers: headers
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
                                                              .and change(
                                                                Ibsoft::ExternalMessaging::Order,
                                                                :count
                                                              ).by(1)
      .and have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'template_type' => 'order',
      'reference_id' => 'standard-9388'
    )
  end

  it 'treats every POST as an independent request' do
    expect do
      2.times { post url, params: simple_payload, headers: headers }
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(2)

    keys = Ibsoft::ExternalMessaging::Delivery.last(2).pluck(:idempotency_key)
    expect(keys.uniq.size).to eq(2)
  end

  it 'rejects unsupported methods, media types, missing credentials, and cross-contract tokens' do
    get url
    expect(response).to have_http_status(:method_not_allowed)
    expect(response.headers['Allow']).to eq('POST')

    post url,
         params: simple_payload,
         headers: headers.merge('Content-Type' => 'application/json')
    expect(response).to have_http_status(:unsupported_media_type)

    post url, params: simple_payload, headers: { 'Content-Type' => 'text/plain' }
    expect(response).to have_http_status(:unauthorized)

    sgp_token = "ibext_#{SecureRandom.urlsafe_base64(32)}"
    create(
      :ibsoft_external_message_endpoint,
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(sgp_token)
    )
    post url,
         params: simple_payload,
         headers: headers.merge('Authorization' => "Bearer #{sgp_token}")
    expect(response).to have_http_status(:unauthorized)
  end
end
