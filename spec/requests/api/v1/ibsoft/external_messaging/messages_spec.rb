require 'rails_helper'

RSpec.describe 'Ibsoft external messaging public endpoint', type: :request do
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
      name: 'ERP principal',
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(raw_token)
    )
  end
  let(:url) { '/chathub-sender/sgp/generico/' }
  let(:simple_message) do
    [
      '[template_name]=ticket_status_updated',
      '[template_language]=en',
      '[body.name]=Cliente Teste',
      '[body.ticket_id]=42'
    ].join('||')
  end
  let(:order_message) do
    [
      '[template_name]=lembrete_fatura_pdf_pix',
      '[template_type]=order',
      '[header_type]=document',
      '[header_link]=https://sistema.asnetwork.net.br/boleto/9388-0CFLCN1OMD.pdf',
      '[header_append_pdf]=false',
      '[body.nome_cliente]=José Augusto Silva',
      '[body.vencimento_fatura]=10/08/2027',
      '[order.reference_id]=9388',
      '[order.total]=64,99',
      '[order.item_name]=Fatura de internet',
      '[order.payment.pix.code]=PIX_COPIA_E_COLA_COMPLETO',
      '[order.payment.pix.merchant_name]=IBSoft Cloud',
      '[order.payment.pix.key]=12345678000199',
      '[order.payment.pix.key_type]=CNPJ',
      '[order.payment.boleto.digitable_line]=00190000090350182490218767625173516510000006499'
    ].join('||')
  end

  before { endpoint }

  it 'accepts the exact GET contract and queues the semantic message', :aggregate_failures do
    expect do
      get url, params: {
        msg: simple_message,
        to: '5575982479788',
        token: raw_token
      }
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
                                                              .and have_enqueued_job(
                                                                Ibsoft::ExternalMessaging::SendDeliveryJob
                                                              )
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
      account_id: account.id,
      inbox_id: channel.inbox.id,
      recipient: '5575982479788',
      status: 'queued'
    )
    expect(delivery.idempotency_key).to start_with('request-')
    expect(delivery.template_components).to include(
      a_hash_including('type' => 'body')
    )
  end

  it 'accepts the exact order format and records only required delivery data', :aggregate_failures do
    get url, params: {
      msg: order_message,
      to: '5575982479788',
      token: raw_token
    }

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'ok' => true,
      'status' => 'accepted',
      'reference_id' => '9388',
      'template_name' => 'lembrete_fatura_pdf_pix',
      'template_type' => 'order'
    )

    delivery = Ibsoft::ExternalMessaging::Delivery.last
    expect(delivery).to have_attributes(
      recipient: '5575982479788',
      template_name: 'lembrete_fatura_pdf_pix',
      template_type: 'order',
      order_reference_id: '9388'
    )
    expect(delivery.idempotency_key).to start_with('request-')
    expect(delivery.template_components).to include(
      a_hash_including('type' => 'header'),
      a_hash_including('type' => 'body'),
      a_hash_including('sub_type' => 'order_details')
    )
  end

  it 'accepts a repeated order as another delivery of the same canonical order' do
    params = { msg: order_message, to: '5575982479788', token: raw_token }
    get url, params: params
    first_delivery = Ibsoft::ExternalMessaging::Delivery.last
    delivery_change = change(Ibsoft::ExternalMessaging::Delivery, :count).by(1)
    job_enqueue = have_enqueued_job(Ibsoft::ExternalMessaging::SendDeliveryJob)
    order_change = not_change(Ibsoft::ExternalMessaging::Order, :count)

    expect do
      get url, params: params
    end.to delivery_change.and(job_enqueue).and(order_change)

    second_delivery = Ibsoft::ExternalMessaging::Delivery.last
    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'ok' => true,
      'reference_id' => '9388'
    )
    expect(second_delivery).not_to eq(first_delivery)
    expect(second_delivery.external_order).to eq(first_delivery.external_order)
  end

  it 'rejects a repeated order when the instance disables resends' do
    params = { msg: order_message, to: '5575982479788', token: raw_token }
    get url, params: params
    endpoint.update!(allow_order_resends: false)
    queued_job_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size

    expect do
      get url, params: params
    end.not_to change(Ibsoft::ExternalMessaging::Delivery, :count)

    expect(response).to have_http_status(:conflict)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(queued_job_count)
    expect(response.parsed_body.dig('error', 'code')).to eq('order_resend_disabled')
  end

  it 'treats repeated standard messages as separate requests' do
    params = { msg: simple_message, to: '5575982479788', token: raw_token }

    expect do
      2.times { get url, params: params }
    end.to change(Ibsoft::ExternalMessaging::Delivery, :count).by(2)
  end

  it 'requires the token query parameter even when a bearer header is present' do
    get url,
        params: { msg: simple_message, to: '5575982479788' },
        headers: { 'Authorization' => "Bearer #{raw_token}" }

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig('error', 'code')).to eq('unauthorized')
  end

  it 'rejects an invalid token' do
    get url, params: {
      msg: simple_message,
      to: '5575982479788',
      token: 'invalid'
    }

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig('error', 'code')).to eq('unauthorized')
  end

  it 'rejects a token issued for a different API contract' do
    endpoint.instance_type = 'sgp_standard'
    allow(Ibsoft::ExternalMessaging::Endpoint).to receive(:authenticate)
      .with(raw_token)
      .and_return(endpoint)

    get url, params: {
      msg: simple_message,
      to: '5575982479788',
      token: raw_token
    }

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig('error', 'code')).to eq('unauthorized')
  end

  it 'rejects a request without msg' do
    get url, params: { to: '5575982479788', token: raw_token }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig('error', 'code')).to eq('payload_required')
  end

  it 'does not expose the superseded JSON API route' do
    post '/api/v1/ibsoft/external_messaging/messages',
         params: { to: '5575982479788' },
         as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'does not expose the previous generic public route' do
    get '/chathub-sender/generico/', params: {
      msg: simple_message,
      to: '5575982479788',
      token: raw_token
    }

    expect(response).to have_http_status(:not_found)
  end

  it 'filters the public contract values from Rails parameter logs' do
    filter = ActiveSupport::ParameterFilter.new(
      Rails.application.config.filter_parameters
    )

    expect(
      filter.filter(
        msg: simple_message,
        to: '5575982479788',
        token: raw_token
      )
    ).to eq(
      msg: '[FILTERED]',
      to: '[FILTERED]',
      token: '[FILTERED]'
    )
  end
end
