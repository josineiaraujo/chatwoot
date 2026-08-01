# frozen_string_literal: true

class Api::V1::Accounts::Ibsoft::InstagramInbound::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization!
  before_action :fetch_instagram_inbox

  private

  def check_admin_authorization!
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end

  def fetch_instagram_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    raise ActiveRecord::RecordNotFound unless @inbox.instagram?
  end
end
