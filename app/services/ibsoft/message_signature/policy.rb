# frozen_string_literal: true

class Ibsoft::MessageSignature::Policy
  def initialize(**context)
    @account = context.fetch(:account)
    @conversation = context.fetch(:conversation)
    @user = context.fetch(:user)
    @params = context.fetch(:params)
    @message_type = context.fetch(:message_type)
    @private_message = context.fetch(:private_message)
    @automation_rule = context.fetch(:automation_rule)
  end

  def native_footer_cleanup?
    human_dashboard_message? && public_outgoing_message? && textual_message?
  end

  def signature_enabled?(content)
    native_footer_cleanup? &&
      content.present? &&
      configuration.enabled_for_inbox?(conversation.inbox_id) &&
      params[:template_params].blank? &&
      params[:campaign_id].blank? &&
      params[:email_html_content].blank? &&
      automation_rule.blank?
  end

  private

  attr_reader :account, :conversation, :user, :params, :message_type, :private_message, :automation_rule

  def configuration
    @configuration ||= Ibsoft::MessageSignature::Configuration.new(account)
  end

  def human_dashboard_message?
    params.instance_of?(ActionController::Parameters) &&
      user.is_a?(User) &&
      params[:sender_type] != 'AgentBot' &&
      !Ibsoft::MessageSignature::RequestContext.external_api_request
  end

  def public_outgoing_message?
    message_type.to_s == 'outgoing' && !ActiveModel::Type::Boolean.new.cast(private_message)
  end

  def textual_message?
    params[:content_type].blank? || params[:content_type].to_s == 'text'
  end
end
