class Api::V1::Accounts::Ibsoft::MessageBroadcast::TemplatesController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  def index
    inbox = Current.account.inboxes.find(params[:inbox_id])
    templates = Ibsoft::MessageBroadcast::TemplateCatalog.new(inbox).call

    render json: { templates: templates }
  rescue Ibsoft::MessageBroadcast::TemplateCatalog::UnsupportedInboxError
    render json: { error: 'unsupported_whatsapp_inbox' }, status: :unprocessable_entity
  end
end
