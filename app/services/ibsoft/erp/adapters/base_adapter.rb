require 'base64'

class Ibsoft::Erp::Adapters::BaseAdapter
  TIMEOUT_SECONDS = 10

  def self.for(connection)
    case connection.provider
    when 'ixc'
      Ibsoft::Erp::Adapters::IxcAdapter.new(connection)
    when 'sgp'
      Ibsoft::Erp::Adapters::SgpAdapter.new(connection)
    else
      new(connection)
    end
  end

  def initialize(connection)
    @connection = connection
  end

  def test_connection
    started_at = monotonic_time
    response = perform_test_request
    duration_ms = elapsed_ms(started_at)

    return success_result(response, duration_ms) if response.code.to_i.between?(200, 299)

    failure_result(:http_error, http_status: response.code.to_i, duration_ms: duration_ms)
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout,
         OpenSSL::SSL::SSLError, URI::InvalidURIError, HTTParty::Error => e
    Rails.logger.warn("[IBSOFT ERP] Connection test failed: #{e.class}")
    failure_result(:request_error, duration_ms: elapsed_ms(started_at))
  end

  private

  attr_reader :connection

  def perform_test_request
    raise NotImplementedError
  end

  def success_result(response, duration_ms)
    Ibsoft::Erp::ConnectionTestResult.success(
      http_status: response.code.to_i,
      duration_ms: duration_ms
    )
  end

  def failure_result(error_type, http_status: nil, duration_ms: nil)
    Ibsoft::Erp::ConnectionTestResult.failure(
      error_type: error_type.to_s,
      http_status: http_status,
      duration_ms: duration_ms
    )
  end

  def credentials
    connection.credentials.to_h.with_indifferent_access
  end

  def base_url
    connection.base_url.to_s.delete_suffix('/')
  end

  def basic_auth_header
    encoded_credentials = Base64.strict_encode64(
      "#{credentials[:username]}:#{credentials[:password]}"
    )

    "Basic #{encoded_credentials}"
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed_ms(started_at)
    return nil if started_at.blank?

    ((monotonic_time - started_at) * 1000).round
  end
end
