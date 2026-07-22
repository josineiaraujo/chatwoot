# frozen_string_literal: true

class Api::V1::Accounts::Ibsoft::MessageSignature::SettingsController <
  Api::V1::Accounts::Ibsoft::MessageSignature::BaseController
  rescue_from Ibsoft::MessageSignature::ConfigurationUpdater::ValidationError, with: :render_validation_error

  def show
    render json: configuration.payload
  end

  def update
    payload = Ibsoft::MessageSignature::ConfigurationUpdater.new(
      account: Current.account,
      params: setting_params
    ).call

    render json: payload
  end

  private

  def configuration
    @configuration ||= Ibsoft::MessageSignature::Configuration.new(Current.account)
  end

  def setting_params
    params.permit(:enabled, inbox_ids: [])
  end

  def render_validation_error(error)
    render json: {
      error: I18n.t("ibsoft_message_signature.errors.#{error.code}")
    }, status: :unprocessable_content
  end
end
