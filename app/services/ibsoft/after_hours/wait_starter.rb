class Ibsoft::AfterHours::WaitStarter
  CONTENT_ATTRIBUTE_KEY = 'ibsoft_after_hours'.freeze

  def initialize(conversation:, decision:)
    @conversation = conversation
    @decision = decision.with_indifferent_access
  end

  def perform
    return result(false, 'policy_not_available') if after_hours_policy.blank? || !after_hours_policy.enabled?

    reservation = nil
    conversation.reload
    conversation.with_lock do
      reservation = eligible_conversation? ? reserve_wait : result(false, 'conversation_not_eligible')
    end
    return reservation if reservation[:applied] == false

    deliver_entry_message(reservation.fetch(:wait))
  end

  private

  attr_reader :conversation, :decision

  def reserve_wait
    wait = Ibsoft::AfterHours::Wait.find_or_initialize_by(conversation: conversation)
    return existing_wait_reservation(wait) if matching_active_wait?(wait)

    wait.assign_attributes(wait_attributes)
    wait.save!

    { applied: true, wait: wait }
  end

  def existing_wait_reservation(wait)
    return result(false, 'already_active', wait_id: wait.id) if wait.entry_message_id.present?

    { applied: true, wait: wait }
  end

  def wait_attributes
    {
      account: conversation.account,
      after_hours_policy: after_hours_policy,
      team: conversation.team,
      exit_command: after_hours_policy.exit_command,
      exit_confirmation_message: after_hours_policy.exit_confirmation_message,
      business_calendar_id: decision[:business_calendar_id],
      business_holiday_id: decision[:business_holiday_id],
      entry_message: nil,
      exit_message: nil,
      status: 'active',
      cause: decision[:outside_business_hours_cause] || 'schedule',
      started_at: Time.current,
      finished_at: nil
    }
  end

  def deliver_entry_message(wait)
    delivery_result = nil
    wait.with_lock do
      delivery_result = deliver_locked(wait)
    end
    delivery_result
  rescue StandardError
    wait.update!(status: 'cancelled', finished_at: Time.current) if wait&.persisted? && wait.active?
    raise
  end

  def deliver_locked(wait)
    wait.reload
    return result(false, 'already_active', wait_id: wait.id) if wait.entry_message_id.present?

    conversation.reload
    return cancel_wait(wait, 'conversation_not_eligible') unless wait.active? && eligible_conversation?

    message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
    wait.update!(entry_message: message)
    result(true, 'wait_started', wait_id: wait.id, message_id: message.id)
  end

  def cancel_wait(wait, status)
    wait.update!(status: 'cancelled', finished_at: Time.current)
    result(false, status, wait_id: wait.id)
  end

  def matching_active_wait?(wait)
    wait.persisted? && wait.active? && wait.after_hours_policy_id == after_hours_policy.id && wait.team_id == conversation.team_id
  end

  def eligible_conversation?
    conversation.open? && conversation.assignee.blank? && conversation.team_id.present?
  end

  def after_hours_policy
    @after_hours_policy ||= Ibsoft::AfterHours::Policy.find_by(
      id: decision[:after_hours_policy_id],
      account_id: conversation.account_id
    )
  end

  def message_params
    {
      content: entry_message,
      private: false,
      content_attributes: {
        CONTENT_ATTRIBUTE_KEY => {
          event: 'wait_started',
          cause: decision[:outside_business_hours_cause] || 'schedule',
          policy_id: after_hours_policy.id
        }
      }
    }
  end

  def entry_message
    return after_hours_policy.holiday_message if decision[:outside_business_hours_cause] == 'holiday'

    after_hours_policy.regular_message
  end

  def result(applied, status, metadata = {})
    { applied: applied, status: status }.merge(metadata)
  end
end
