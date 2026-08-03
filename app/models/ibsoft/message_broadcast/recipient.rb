# == Schema Information
#
# Table name: ibsoft_message_broadcast_recipients
#
#  id                       :bigint           not null, primary key
#  customer_name            :string           not null
#  enqueued_at              :datetime
#  error_code               :string
#  error_message            :text
#  fallback_phone           :string
#  phone_status             :string           default("pending"), not null
#  phone_used               :string
#  primary_phone            :string
#  processing_started_at    :datetime
#  status                   :string           default("pending"), not null
#  template_variable_values :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  broadcast_id             :bigint           not null
#  conversation_id          :bigint
#  external_customer_id     :string           not null
#  message_id               :bigint
#  meta_message_id          :string
#
# Indexes
#
#  idx_ibsoft_broadcast_recipients_customer                      (broadcast_id,external_customer_id) UNIQUE
#  idx_ibsoft_broadcast_recipients_dispatch                      (status,enqueued_at)
#  idx_ibsoft_broadcast_recipients_meta_message                  (meta_message_id) UNIQUE WHERE (meta_message_id IS NOT NULL)
#  index_ibsoft_message_broadcast_recipients_on_broadcast_id     (broadcast_id)
#  index_ibsoft_message_broadcast_recipients_on_conversation_id  (conversation_id)
#  index_ibsoft_message_broadcast_recipients_on_message_id       (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (broadcast_id => ibsoft_message_broadcasts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (message_id => messages.id)
#
class Ibsoft::MessageBroadcast::Recipient < ApplicationRecord
  self.table_name = 'ibsoft_message_broadcast_recipients'

  STATUSES = %w[pending queued processing accepted sent delivered read failed skipped uncertain].freeze
  PHONE_STATUSES = %w[pending primary fallback unavailable invalid].freeze

  belongs_to :broadcast,
             class_name: 'Ibsoft::MessageBroadcast::Broadcast',
             inverse_of: :recipients
  belongs_to :conversation, class_name: '::Conversation', optional: true
  belongs_to :message, class_name: '::Message', optional: true

  validates :external_customer_id, :customer_name, presence: true
  validates :external_customer_id, uniqueness: { scope: :broadcast_id }
  validates :status, inclusion: { in: STATUSES }
  validates :phone_status, inclusion: { in: PHONE_STATUSES }

  def payload
    {
      id: id,
      external_customer_id: external_customer_id,
      customer_name: customer_name,
      primary_phone: primary_phone,
      fallback_phone: fallback_phone,
      phone_used: phone_used,
      phone_status: phone_status,
      status: status,
      meta_message_id: meta_message_id,
      template_variable_values: template_variable_values,
      conversation_id: conversation_id,
      conversation_display_id: conversation&.display_id,
      message_id: message_id,
      error_code: error_code,
      error_message: error_message,
      updated_at: updated_at
    }
  end
end
