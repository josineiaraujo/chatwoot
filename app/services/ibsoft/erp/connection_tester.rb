class Ibsoft::Erp::ConnectionTester
  def initialize(connection)
    @connection = connection
  end

  def call
    result = adapter.test_connection
    @connection.update!(last_tested_at: Time.current, last_test_status: result.status)
    result
  end

  private

  def adapter
    Ibsoft::Erp::Adapters::BaseAdapter.for(@connection)
  end
end
