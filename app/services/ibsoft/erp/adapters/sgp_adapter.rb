class Ibsoft::Erp::Adapters::SgpAdapter < Ibsoft::Erp::Adapters::BaseAdapter
  private

  def perform_test_request
    HTTParty.post(
      client_list_url,
      headers: request_headers,
      body: test_payload,
      timeout: TIMEOUT_SECONDS
    )
  end

  def client_list_url
    return "#{base_url}/ura/clientes/" if base_url.end_with?('/api')
    return "#{base_url}/clientes/" if base_url.end_with?('/api/ura')

    "#{base_url}/api/ura/clientes/"
  end

  def request_headers
    headers = { 'Accept' => 'application/json' }
    headers['Authorization'] = basic_auth_header if connection.auth_type == 'basic'
    headers
  end

  def test_payload
    payload = {
      offset: 0,
      limit: 1,
      omitir_contratos: true,
      omitir_titulos: true
    }

    return payload if connection.auth_type == 'basic'

    payload.merge(app: credentials[:app], token: credentials[:token])
  end
end
