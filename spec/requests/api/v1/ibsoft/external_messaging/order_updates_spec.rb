require 'rails_helper'

RSpec.describe 'Ibsoft external order update endpoint', type: :request do
  let(:raw_token) { "ibext_#{SecureRandom.urlsafe_base64(32)}" }
  let(:endpoint) do
    create(
      :ibsoft_external_message_endpoint,
      token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(raw_token)
    )
  end
  let(:opening_delivery) do
    create(
      :ibsoft_external_message_delivery,
      endpoint: endpoint,
      account: endpoint.account,
      inbox: endpoint.inbox,
      template_type: 'order',
      order_reference_id: '9388',
      status: 'accepted',
      meta_message_id: 'wamid.opening-9388'
    )
  end
  let!(:order) do
    create(
      :ibsoft_external_message_order,
      opening_delivery: opening_delivery,
      account: endpoint.account,
      inbox: endpoint.inbox,
      reference_id: '9388'
    )
  end
  let(:url) { '/chathub-sender/sgp/pedido/' }

  it 'accepts the shared GET contract and queues work without calling Meta synchronously' do
    expect do
      get url, params: {
        fatura_id: '9388',
        status: 'processando',
        token: raw_token
      }
    end.to(
      change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(1)
        .and(
          have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob)
        )
        .and(not_change(Conversation, :count))
        .and(not_change(Message, :count))
    )

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'ok' => true,
      'status' => 'accepted',
      'message_id' => nil,
      'reference_id' => '9388',
      'order_status' => 'processing',
      'visible_message' => true
    )
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'accepts JSON and text bodies using Bearer authentication' do
    post url,
         params: {
           reference_id: '9388',
           payment_status: 'captured'
         }.to_json,
         headers: {
           'Authorization' => "Bearer #{raw_token}",
           'Content-Type' => 'application/json'
         }

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body['payment_status']).to eq('captured')

    order.update!(payment_status: nil)
    post url,
         params: '[fatura_id]=9388||[payment_status]=pending',
         headers: {
           'Authorization' => "Bearer #{raw_token}",
           'Content-Type' => 'text/plain'
         }

    expect(response).to have_http_status(:accepted)
  end

  it 'returns unchanged without creating or enqueueing work' do
    updates_before = Ibsoft::ExternalMessaging::OrderUpdate.count

    expect do
      get url, params: {
        fatura_id: '9388',
        order_status: 'pending',
        token: raw_token
      }
    end.not_to have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob)

    expect(Ibsoft::ExternalMessaging::OrderUpdate.count).to eq(updates_before)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'status' => 'unchanged',
      'visible_message' => false
    )
  end

  it 'rejects an unknown or not-yet-accepted order' do
    get url, params: {
      fatura_id: 'missing',
      status: 'processing',
      token: raw_token
    }
    expect(response).to have_http_status(:not_found)

    opening_delivery.update!(status: 'queued', meta_message_id: nil)
    get url, params: {
      fatura_id: '9388',
      status: 'processing',
      token: raw_token
    }
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig('error', 'code')).to eq('order_update_not_ready')
  end

  it 'does not accept query authentication for POST' do
    post "#{url}?token=#{raw_token}",
         params: { fatura_id: '9388', status: 'processing' }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not find an order from another account or channel' do
    foreign_order = create(:ibsoft_external_message_order, reference_id: 'foreign-1')

    get url, params: {
      fatura_id: foreign_order.reference_id,
      status: 'processing',
      token: raw_token
    }

    expect(response).to have_http_status(:not_found)
  end

  it 'filters business fields from Rails parameter logs' do
    filter = ActiveSupport::ParameterFilter.new(
      Rails.application.config.filter_parameters
    )

    expect(
      filter.filter(
        fatura_id: '9388',
        message: 'Sensitive',
        payment_timestamp: '1783735200'
      )
    ).to eq(
      fatura_id: '[FILTERED]',
      message: '[FILTERED]',
      payment_timestamp: '[FILTERED]'
    )
  end

  context 'when the order belongs to the IXC family' do
    let(:endpoint) do
      create(
        :ibsoft_external_message_endpoint,
        instance_type: 'ixc',
        token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(raw_token)
      )
    end
    let(:url) { '/chathub-sender/ixc/pedido/' }
    let(:username) do
      Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).username
    end
    let(:ixc_params) do
      {
        user: username,
        pw: raw_token,
        dest: opening_delivery.recipient,
        text: '[fatura_id]=9388||[status]=processando'
      }
    end

    it 'accepts the exact IXC GET envelope and only queues the update' do
      expect do
        get url, params: ixc_params
      end.to(
        change(Ibsoft::ExternalMessaging::OrderUpdate, :count).by(1)
          .and(have_enqueued_job(Ibsoft::ExternalMessaging::SendOrderUpdateJob))
          .and(not_change(Conversation, :count))
          .and(not_change(Message, :count))
      )

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        'reference_id' => '9388',
        'order_status' => 'processing',
        'visible_message' => true
      )
    end

    it 'accepts the exact IXC envelope as JSON' do
      post url,
           params: ixc_params.merge(
             text: '[reference_id]=9388||[payment_status]=captured'
           ).to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        'reference_id' => '9388',
        'payment_status' => 'captured'
      )
    end

    it 'requires all four IXC envelope fields' do
      get url, params: ixc_params.except(:dest)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'code')).to eq('ixc_field_required')
    end

    it 'rejects invalid and cross-family credentials' do
      get url, params: ixc_params.merge(pw: 'invalid')

      expect(response).to have_http_status(:unauthorized)

      sgp_token = 'another-family-secret'
      create(
        :ibsoft_external_message_endpoint,
        token_digest: Ibsoft::ExternalMessaging::Endpoint.digest_token(sgp_token)
      )
      get url, params: ixc_params.merge(user: 'ixc_999', pw: sgp_token)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig('error', 'code')).to eq('ixc_unauthorized')
    end

    it 'keeps order lookup scoped to the IXC account and channel' do
      foreign_endpoint = create(
        :ibsoft_external_message_endpoint,
        instance_type: 'ixc'
      )
      foreign_secret = foreign_endpoint.rotate_token!
      foreign_username = Ibsoft::ExternalMessaging::InstanceCredentials
                         .new(endpoint: foreign_endpoint)
                         .username

      get url, params: ixc_params.merge(user: foreign_username, pw: foreign_secret)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig('error', 'code')).to eq('order_update_not_found')
    end

    it 'does not update an order when dest belongs to another recipient' do
      get url, params: ixc_params.merge(dest: '5511999999999')

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig('error', 'code')).to eq('order_update_not_found')
    end

    it 'does not accept the former HTTP Basic shape' do
      get url,
          params: { fatura_id: '9388', status: 'processando' },
          headers: { 'Authorization' => "Basic #{raw_token}" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'code')).to eq('ixc_field_required')
    end
  end
end
