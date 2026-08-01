class Api::V1::Accounts::Ibsoft::ExternalMessaging::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization!

  private

  def check_admin_authorization!
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end

  def whatsapp_cloud_inboxes
    Current.account.inboxes
           .where(channel_type: 'Channel::Whatsapp')
           .includes(:channel)
           .select do |inbox|
      inbox.channel.provider == 'whatsapp_cloud'
    end
  end
end
