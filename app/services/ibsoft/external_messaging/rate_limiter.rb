class Ibsoft::ExternalMessaging::RateLimiter
  WINDOW_TTL = 3.seconds.to_i

  def initialize(delivery: nil, record: nil)
    @record = record || delivery
  end

  def acquire
    count = initialize_window || Redis::Alfred.incr(rate_key)
    count <= record.endpoint.effective_rate_limit_per_second
  end

  private

  attr_reader :record

  def initialize_window
    result = Redis::Alfred.set(rate_key, 1, nx: true, ex: WINDOW_TTL)
    1 if result
  end

  def rate_key
    "ibsoft:external_messaging:inbox:#{record.inbox_id}:rate:#{Time.current.to_i}"
  end
end
