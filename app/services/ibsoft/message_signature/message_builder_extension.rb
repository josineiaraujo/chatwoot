# frozen_string_literal: true

module Ibsoft::MessageSignature::MessageBuilderExtension
  private

  def message_params
    attributes = super
    policy = message_signature_policy
    content = attributes[:content]

    if policy.native_footer_cleanup?
      content = Ibsoft::MessageSignature::NativeFooterSanitizer.new(
        content: content,
        native_signature: @user.message_signature
      ).call
    end

    if policy.signature_enabled?(content)
      content = Ibsoft::MessageSignature::HeaderFormatter.new(
        content: content,
        agent_name: @user.name
      ).call
    end

    attributes.merge(content: content)
  end

  def message_signature_policy
    Ibsoft::MessageSignature::Policy.new(
      account: @account,
      conversation: @conversation,
      user: @user,
      params: @params,
      message_type: @message_type,
      private_message: @private,
      automation_rule: @automation_rule
    )
  end
end
