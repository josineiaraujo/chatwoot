class Ibsoft::Erp::ConnectionTestResult
  attr_reader :status, :http_status, :error_type, :duration_ms

  def self.success(http_status:, duration_ms:)
    new(status: 'success', http_status: http_status, duration_ms: duration_ms)
  end

  def self.failure(error_type:, http_status: nil, duration_ms: nil)
    new(status: 'failed', error_type: error_type, http_status: http_status, duration_ms: duration_ms)
  end

  def initialize(status:, http_status: nil, error_type: nil, duration_ms: nil)
    @status = status
    @http_status = http_status
    @error_type = error_type
    @duration_ms = duration_ms
  end

  def success?
    status == 'success'
  end

  def payload
    {
      success: success?,
      status: status,
      http_status: http_status,
      error_type: error_type,
      duration_ms: duration_ms
    }
  end
end
