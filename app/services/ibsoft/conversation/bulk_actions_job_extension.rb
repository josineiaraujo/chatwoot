# frozen_string_literal: true

module Ibsoft::Conversation::BulkActionsJobExtension
  def perform(account:, params:, user:)
    result = super

    Ibsoft::Conversation::BulkActionStatsNotifier.new(
      account: account,
      user: user,
      params: params,
      conversations: records
    ).perform

    result
  end
end
