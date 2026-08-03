class Ibsoft::MessageBroadcast::DirectRecipientDelivery
  Result = Data.define(:meta_message_id, :conversation, :message)

  def initialize(broadcast:, recipient:)
    @broadcast = broadcast
    @recipient = recipient
  end

  def call(phone_candidate)
    result = Ibsoft::MessageBroadcast::MetaTemplateClient.new(
      broadcast: broadcast,
      recipient: recipient
    ).call(phone_candidate)

    Result.new(meta_message_id: result.message_id, conversation: nil, message: nil)
  end

  private

  attr_reader :broadcast, :recipient
end
