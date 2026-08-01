# == Schema Information
#
# Table name: ibsoft_external_message_deliveries
#
#  id                    :bigint           not null, primary key
#  accepted_at           :datetime
#  attempts_count        :integer          default(0), not null
#  delivered_at          :datetime
#  enqueued_at           :datetime
#  error_code            :string
#  error_message         :text
#  failed_at             :datetime
#  idempotency_key       :string           not null
#  message_content       :text             not null
#  meta_http_status      :integer
#  order_pix_key         :text
#  processing_started_at :datetime
#  read_at               :datetime
#  received_at           :datetime         not null
#  recipient             :string           not null
#  request_fingerprint   :string           not null
#  status                :string           default("queued"), not null
#  template_components   :jsonb            not null
#  template_language     :string           not null
#  template_name         :string           not null
#  template_type         :string           default("standard"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  endpoint_id           :bigint           not null
#  inbox_id              :bigint           not null
#  meta_message_id       :string
#  order_reference_id    :string
#
# Indexes
#
#  idx_ibsoft_ext_deliveries_endpoint_created              (endpoint_id,created_at)
#  idx_ibsoft_ext_deliveries_endpoint_recipient            (endpoint_id,recipient,created_at)
#  idx_ibsoft_external_deliveries_account_created          (account_id,created_at)
#  idx_ibsoft_external_deliveries_dispatch                 (status,enqueued_at)
#  idx_ibsoft_external_deliveries_endpoint                 (endpoint_id)
#  idx_ibsoft_external_deliveries_idempotency              (endpoint_id,idempotency_key) UNIQUE
#  idx_ibsoft_external_deliveries_meta_message             (inbox_id,meta_message_id) UNIQUE WHERE (meta_message_id IS NOT NULL)
#  index_ibsoft_external_message_deliveries_on_account_id  (account_id)
#  index_ibsoft_external_message_deliveries_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (endpoint_id => ibsoft_external_message_endpoints.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class Ibsoft::ExternalMessaging::Delivery < ApplicationRecord
  self.table_name = 'ibsoft_external_message_deliveries'

  STATUSES = %w[queued processing accepted sent delivered read failed uncertain].freeze
  TEMPLATE_TYPES = %w[standard order].freeze

  encrypts :order_pix_key if Chatwoot.encryption_configured?

  belongs_to :endpoint,
             class_name: 'Ibsoft::ExternalMessaging::Endpoint',
             inverse_of: :deliveries
  belongs_to :account
  belongs_to :inbox
  has_one :external_order,
          class_name: 'Ibsoft::ExternalMessaging::Order',
          foreign_key: :opening_delivery_id,
          inverse_of: :opening_delivery,
          dependent: :restrict_with_error

  validates :idempotency_key,
            :request_fingerprint,
            :recipient,
            :template_name,
            :template_language,
            :message_content,
            :received_at,
            presence: true
  validates :idempotency_key, uniqueness: { scope: :endpoint_id }
  validates :status, inclusion: { in: STATUSES }
  validates :template_type, inclusion: { in: TEMPLATE_TYPES }
  validates :order_reference_id, presence: true, if: :order_template?
  validate :tenant_matches_endpoint
  validate :order_pix_key_encryption_available

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def order_template?
    template_type == 'order'
  end

  def payload
    identity_payload.merge(
      template_payload,
      status_payload,
      timestamp_payload
    )
  end

  private

  def identity_payload
    {
      id: id,
      endpoint_id: endpoint_id,
      endpoint_name: endpoint.name,
      inbox_id: inbox_id,
      inbox_name: inbox.name,
      idempotency_key: idempotency_key,
      recipient: recipient
    }
  end

  def template_payload
    {
      template_name: template_name,
      template_language: template_language,
      template_type: template_type,
      message_content: message_content,
      order_reference_id: order_reference_id
    }
  end

  def status_payload
    {
      status: status,
      meta_message_id: meta_message_id,
      meta_http_status: meta_http_status,
      error_code: error_code,
      error_message: error_message,
      attempts_count: attempts_count
    }
  end

  def timestamp_payload
    {
      received_at: received_at,
      accepted_at: accepted_at,
      delivered_at: delivered_at,
      read_at: read_at,
      failed_at: failed_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def tenant_matches_endpoint
    return if endpoint.blank?
    return if endpoint.account_id == account_id && endpoint.inbox_id == inbox_id

    errors.add(:endpoint, :invalid)
  end

  def order_pix_key_encryption_available
    return if order_pix_key.blank? || !Rails.env.production? || Chatwoot.encryption_configured?

    errors.add(:order_pix_key, :encryption_not_configured)
  end
end
