class Ibsoft::Erp::Adapters::IxcAdapter < Ibsoft::Erp::Adapters::BaseAdapter
  private

  def perform_test_request
    HTTParty.get(
      client_list_url,
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => basic_auth_header,
        'ixcsoft' => 'listar'
      },
      body: test_payload.to_json,
      timeout: TIMEOUT_SECONDS
    )
  end

  def client_list_url
    return "#{base_url}/cliente" if base_url.end_with?('/webservice/v1')

    "#{base_url}/webservice/v1/cliente"
  end

  def test_payload
    {
      qtype: 'cliente.id',
      query: '1',
      oper: '>=',
      page: '1',
      rp: '1',
      sortname: 'cliente.id',
      sortorder: 'desc'
    }
  end
end
