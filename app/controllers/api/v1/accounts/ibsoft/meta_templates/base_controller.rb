class Api::V1::Accounts::Ibsoft::MetaTemplates::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization!
  before_action :set_inbox

  rescue_from Ibsoft::MetaTemplates::Client::Error, with: :render_meta_error
  rescue_from Ibsoft::MetaTemplates::TemplatePayload::ValidationError, with: :render_validation_error
  rescue_from Ibsoft::MetaTemplates::MediaUploader::Error, with: :render_upload_error

  private

  attr_reader :inbox

  def check_admin_authorization!
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end

  def set_inbox
    @inbox = Current.account.inboxes.includes(:channel).find(params[:inbox_id])
    return if whatsapp_cloud_channel?

    render json: {
      error: 'unsupported_channel',
      message: I18n.t('ibsoft_meta_templates.errors.unsupported_channel')
    }, status: :unprocessable_entity
  end

  def whatsapp_cloud_channel?
    inbox.channel.is_a?(Channel::Whatsapp) && inbox.channel.provider == 'whatsapp_cloud'
  end

  def template_catalog
    @template_catalog ||= Ibsoft::MetaTemplates::Catalog.new(inbox)
  end

  def render_meta_error(error)
    render json: {
      error: error.code,
      message: error.message
    }, status: error.http_status || :bad_gateway
  end

  def render_validation_error(error)
    render json: {
      error: 'validation_failed',
      message: I18n.t('ibsoft_meta_templates.errors.validation_failed'),
      details: error.errors
    }, status: :unprocessable_entity
  end

  def render_upload_error(error)
    render json: {
      error: error.code,
      message: error.message
    }, status: :unprocessable_entity
  end
end
