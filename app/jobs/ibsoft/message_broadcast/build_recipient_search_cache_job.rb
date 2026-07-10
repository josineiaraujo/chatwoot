class Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob < ApplicationJob
  queue_as :medium

  def perform(payload)
    payload = payload.with_indifferent_access
    account = Account.find_by(id: payload[:account_id])
    connection = Ibsoft::Erp::Connection.find_by(id: payload[:connection_id], account_id: payload[:account_id])
    return if account.blank? || connection.blank?

    Ibsoft::MessageBroadcast::RecipientSearch.new(
      account: account,
      connection: connection
    ).build_cache(
      mode: payload[:mode],
      filters: payload[:filters],
      token: payload[:token],
      lock_token: payload[:lock_token]
    )
  end
end
