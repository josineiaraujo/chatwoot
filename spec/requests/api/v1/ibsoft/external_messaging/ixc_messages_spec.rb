require 'rails_helper'

RSpec.describe 'Ibsoft external messaging IXC endpoint', type: :request do
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
  let(:password) { "ibext_#{SecureRandom.urlsafe_base64(32)}" }
  let(:endpoint) do
    create(
      :ibsoft_external_message_endpoint,
      account: account,
      inbox: channel.inbox,
      created_by: admin,
      instance_type: 'ixc',
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(password)
    )
  end
  let(:username) do
    Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).username
  end
  let(:text) do
    [
      '[template_name]=ticket_status_updated',
      '[template_language]=en',
      '[body.name]=Cliente IXC',
      '[body.ticket_id]=42'
    ].join('||')
  end
  let(:order_reference) { "ixc-#{SecureRandom.hex(6)}" }
  let(:order_text) do
    [
      '[template_name]=lembrete_fatura_pdf_pix',
      '[template_type]=order',
      '[header_type]=document',
      '[header_link]=https://sistema.example/fatura.pdf',
      '[header_append_pdf]=false',
      '[body.nome_cliente]=Cliente IXC',
      '[body.vencimento_fatura]=10/08/2027',
      "[order.reference_id]=#{order_reference}",
      '[order.total]=64,99',
      '[order.item_name]=Fatura de internet',
      '[order.payment.pix.code]=PIX_COPIA_E_COLA',
      '[order.payment.pix.merchant_name]=IBSoft Cloud',
      '[order.payment.pix.key]=12345678000199',
      '[order.payment.pix.key_type]=CNPJ',
      '[order.payment.boleto.digitable_line]=00190000090350182490218767625173516510000006499'
    ].join('||')
  end
  let(:envelope) do
    {
      user: username,
      pw: password,
      dest: '+55 (75) 98247-9788',
      text: text
    }
  end
  let(:url) { '/chathub-sender/ixc/' }

  before { endpoint }

  it 'accepts the native IXC GET contract and queues it without creating a conversation', :aggregate_failures do
    expect do
      get url, params: envelope
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
                                                              .and have_enqueued_job(
                                                                Ibsoft::ExternalMessaging::SendDeliveryJob
                                                              )
      .and not_change(Conversation, :count)
      .and not_change(Message, :count)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'ok' => true,
      'status' => 'accepted',
      'template_name' => 'ticket_status_updated'
    )
    expect(Ibsoft::ExternalMessaging::Delivery.last).to have_attributes(
      endpoint_id: endpoint.id,
      recipient: '5575982479788',
      status: 'queued'
    )
  end

  it 'accepts both URL forms without redirecting' do
    get '/chathub-sender/ixc', params: envelope

    expect(response).to have_http_status(:accepted)
  end

  it 'processes a complete IXC order through the shared builders and durable queue', :aggregate_failures do
    expect do
      get url, params: envelope.merge(text: order_text)
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
                                                              .and change(
                                                                Ibsoft::ExternalMessaging::Order,
                                                                :count
                                                              ).by(1)
      .and have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob)
      .and not_change(Conversation, :count)
      .and not_change(Message, :count)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'template_name' => 'lembrete_fatura_pdf_pix',
      'template_type' => 'order',
      'reference_id' => order_reference
    )

    delivery = Ibsoft::ExternalMessaging::Delivery.last
    expect(delivery).to have_attributes(
      endpoint_id: endpoint.id,
      recipient: '5575982479788',
      order_reference_id: order_reference,
      status: 'queued'
    )
    expect(delivery.template_components).to include(
      a_hash_including('type' => 'header'),
      a_hash_including('type' => 'body'),
      a_hash_including('sub_type' => 'order_details')
    )
  end

  it 'accepts form and JSON POST requests' do
    post url, params: envelope
    expect(response).to have_http_status(:accepted)

    post url, params: envelope, as: :json
    expect(response).to have_http_status(:accepted)
    expect(Ibsoft::ExternalMessaging::Delivery.where(endpoint: endpoint).count).to eq(2)
  end

  it 'accepts a matching destination inside text without persisting the envelope credentials' do
    get url, params: envelope.merge(text: "#{text}||[to]=5575982479788")

    expect(response).to have_http_status(:accepted)
    delivery = Ibsoft::ExternalMessaging::Delivery.last
    expect(delivery.template_components.to_json).not_to include(
      username,
      password,
      '"to"'
    )
  end

  it 'rejects invalid credentials, cross-contract secrets, and recipient conflicts' do
    get url, params: envelope.merge(user: 'invalid')
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig('error', 'code')).to eq('ixc_unauthorized')

    endpoint.update!(instance_type: 'sgp_generic')
    get url, params: envelope
    expect(response).to have_http_status(:unauthorized)

    endpoint.update!(instance_type: 'ixc')
    get url, params: envelope.merge(text: "#{text}||[to]=5511999999999")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig('error', 'code')).to eq('ixc_recipient_conflict')
  end

  it 'returns contract-specific method and content-type errors' do
    put url, params: envelope

    expect(response).to have_http_status(:method_not_allowed)
    expect(response.headers['Allow']).to eq('GET, POST')
    expect(response.parsed_body.dig('error', 'code')).to eq('ixc_method_not_allowed')

    post url,
         params: URI.encode_www_form(envelope),
         headers: { 'CONTENT_TYPE' => 'text/plain' }

    expect(response).to have_http_status(:unsupported_media_type)
    expect(response.parsed_body.dig('error', 'code')).to eq('ixc_content_type_invalid')
  end

  it 'filters every IXC envelope value from Rails parameter logs' do
    filter = ActiveSupport::ParameterFilter.new(
      Rails.application.config.filter_parameters
    )

    expect(filter.filter(envelope)).to eq(
      user: '[FILTERED]',
      pw: '[FILTERED]',
      dest: '[FILTERED]',
      text: '[FILTERED]'
    )

    expect(filter.filter(username: 'visible', user_id: 42, context: 'visible')).to eq(
      username: 'visible',
      user_id: 42,
      context: 'visible'
    )
  end
end
