class Ibsoft::Conversation::ForceOpenOnAgentCreatedConversation
  ATTRIBUTE_KEY = 'ibsoft_force_open_on_create'.freeze
  BOOLEAN = ActiveModel::Type::Boolean.new

  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    return false unless flagged?

    remove_attribute
    return false unless eligible?

    @conversation.status = :open
    true
  end

  private

  def flagged?
    BOOLEAN.cast(attribute_value)
  end

  def attribute_value
    attributes[ATTRIBUTE_KEY] || attributes[ATTRIBUTE_KEY.to_sym]
  end

  def remove_attribute
    attributes.delete(ATTRIBUTE_KEY)
    attributes.delete(ATTRIBUTE_KEY.to_sym)
  end

  def attributes
    @conversation.additional_attributes ||= {}
  end

  def eligible?
    return false if @conversation.contact&.blocked?
    return false if @conversation.campaign_id.present? || @conversation.campaign.present?
    return false if Current.user.blank?
    return false if @conversation.assignee_id.blank?

    @conversation.assignee_id.to_i == Current.user.id.to_i
  end
end
