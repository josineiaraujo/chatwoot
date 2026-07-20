class Ibsoft::MessageBroadcast::BroadcastExecutionClaim
  def initialize(broadcast:)
    @broadcast = broadcast
  end

  def acquire
    now = Time.current
    # Conditional SQL update is the compare-and-swap boundary between workers.
    # rubocop:disable Rails/SkipsModelValidations
    claimed = Ibsoft::MessageBroadcast::Broadcast
              .where(id: broadcast.id, status: 'queued')
              .update_all(
                status: 'running',
                started_at: now,
                finished_at: nil,
                updated_at: now
              )
    # rubocop:enable Rails/SkipsModelValidations

    broadcast.reload if claimed == 1
    claimed == 1
  end

  private

  attr_reader :broadcast
end
