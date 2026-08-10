# frozen_string_literal: true

class Ibsoft::Conversation::BulkActionStatsNotifier
  EVENT_NAME = 'ibsoft.conversation.bulk_action_completed'
  COUNT_AFFECTING_FIELDS = %w[assignee_id status team_id].freeze

  def initialize(account:, user:, params:, conversations:)
    @account = account
    @user = user
    @params = params
    @conversations = conversations
  end

  def perform
    return unless count_affecting_update?

    inbox_ids = Array(@conversations).filter_map(&:inbox_id).uniq
    return if inbox_ids.blank?

    tokens = recipient_tokens(inbox_ids)
    return if tokens.blank?

    ActionCableBroadcastJob.perform_later(
      tokens,
      EVENT_NAME,
      { account_id: @account.id }
    )
  end

  private

  def count_affecting_update?
    fields = @params[:fields] || @params['fields']
    return false unless fields.respond_to?(:keys)

    fields.keys.map(&:to_s).intersect?(COUNT_AFFECTING_FIELDS)
  end

  def recipient_tokens(inbox_ids)
    member_tokens = InboxMember.joins(:user)
                               .where(inbox_id: inbox_ids)
                               .pluck('users.pubsub_token')

    ([@user.pubsub_token] + member_tokens + @account.administrators.pluck(:pubsub_token))
      .compact_blank
      .uniq
      .sort
  end
end
