class Ibsoft::MessageBroadcast::RateLimiter
  WINDOW_TTL = 3.seconds.to_i

  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def acquire
    count = initialize_window || Redis::Alfred.incr(rate_key)
    count <= limit_per_second
  end

  private

  attr_reader :broadcast

  def initialize_window
    result = Redis::Alfred.set(rate_key, 1, nx: true, ex: WINDOW_TTL)
    1 if result
  end

  def limit_per_second
    ENV.fetch('IBSOFT_MESSAGE_BROADCAST_RATE_LIMIT_PER_SECOND', 10).to_i.clamp(1, 80)
  end

  def rate_key
    "ibsoft:message_broadcast:inbox:#{broadcast.inbox_id}:rate:#{Time.current.to_i}"
  end
end
