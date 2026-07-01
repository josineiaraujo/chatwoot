class Ibsoft::ConversationDistribution::RedistributionResultBuilder
  def self.build(event:, policy:, outcome:)
    new(event: event, policy: policy, outcome: outcome).perform
  end

  def self.summary(results)
    {
      scanned: results.length,
      redistributed: results.count { |result| result[:status] == 'redistributed' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      ignored: results.count { |result| result[:status] == 'ignored' },
      by_reason: results.pluck(:reason).tally
    }
  end

  def initialize(event:, policy:, outcome:)
    @event = event
    @policy = policy
    @outcome = outcome
  end

  def perform
    payload.tap do |item|
      item[:decision] = outcome[:decision] if outcome[:decision].present?
    end
  end

  private

  attr_reader :event, :policy, :outcome

  def payload
    conversation_payload
      .merge(outcome_payload)
      .merge(assignment_payload)
      .merge(trigger_payload)
      .merge(policy_payload)
  end

  def conversation_payload
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      team_id: conversation.team_id
    }
  end

  def outcome_payload
    {
      status: outcome[:status],
      reason: outcome[:reason]
    }
  end

  def assignment_payload
    {
      previous_assignee_id: event.new_assignee_id,
      new_assignee_id: assignee&.id,
      new_assignee_name: assignee&.name
    }
  end

  def trigger_payload
    {
      trigger_event_id: event.id,
      trigger_event_type: event.event_type,
      trigger_event_created_at: event.created_at.iso8601
    }
  end

  def policy_payload
    {
      timeout_minutes: policy.timeout_minutes,
      policy: policy.payload
    }
  end

  def conversation
    @conversation ||= event.conversation
  end

  def assignee
    outcome[:assignee]
  end
end
