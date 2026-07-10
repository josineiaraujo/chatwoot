class Ibsoft::MessageBroadcast::SendBroadcastJob < ApplicationJob
  queue_as :low

  def perform(broadcast_id)
    broadcast = Ibsoft::MessageBroadcast::Broadcast.find(broadcast_id)
    Ibsoft::MessageBroadcast::BroadcastSender.new(broadcast: broadcast).call
  end
end
