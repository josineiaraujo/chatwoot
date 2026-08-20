class Ibsoft::ConversationDistribution::ActivityMessageNotifier
  ACTION_KEYS = {
    assignment_completed: 'ibsoft.conversation_distribution.activity.assignment_completed',
    agent_claim_completed: 'ibsoft.conversation_distribution.activity.agent_claim_completed',
    automation_close_completed: 'ibsoft.conversation_distribution.activity.automation_close_completed',
    automation_handoff_completed: 'ibsoft.conversation_distribution.activity.automation_handoff_completed',
    queue_returned: 'ibsoft.conversation_distribution.activity.queue_returned',
    queue_transferred: 'ibsoft.conversation_distribution.activity.queue_transferred',
    redistribution_completed: 'ibsoft.conversation_distribution.activity.redistribution_completed'
  }.freeze

  def initialize(conversation:, action:, **context)
    @conversation = conversation
    @action = action&.to_sym
    @assignee = context[:assignee]
    @previous_assignee = context[:previous_assignee]
    @target_team = context[:target_team]
    @stale_after_minutes = context[:stale_after_minutes]
  end

  def perform
    return skipped('missing_conversation') if conversation.blank?

    Conversations::ActivityMessageJob.perform_later(
      conversation,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: activity_content
    )

    { applied: true, status: 'enqueued' }
  rescue StandardError => e
    Rails.logger.error("[Ibsoft::ConversationDistribution] activity message failed: #{e.class} - #{e.message}")
    { applied: false, status: 'error', error: e.class.name }
  end

  private

  attr_reader :conversation, :action, :assignee, :previous_assignee, :target_team, :stale_after_minutes

  def skipped(status)
    { applied: false, status: status }
  end

  def activity_content
    I18n.with_locale(locale) do
      I18n.t(ACTION_KEYS.fetch(action), **translation_params, raise: true)
    end
  end

  def locale
    conversation.account&.locale.presence || I18n.default_locale
  end

  def translation_params
    {
      assignee_name: assignee_name(assignee),
      previous_assignee_name: assignee_name(previous_assignee),
      target_team_name: team_name(target_team),
      stale_after_minutes: stale_after_minutes
    }
  end

  def assignee_name(user)
    user&.name.presence || I18n.t('ibsoft.conversation_distribution.activity.unknown_assignee', locale: locale)
  end

  def team_name(team)
    team&.name.presence || I18n.t('ibsoft.conversation_distribution.activity.unknown_team', locale: locale)
  end
end
