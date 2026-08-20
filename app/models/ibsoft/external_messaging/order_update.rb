# == Schema Information
#
# Table name: ibsoft_external_message_order_updates
#
#  id                    :bigint           not null, primary key
#  accepted_at           :datetime
#  attempts_count        :integer          default(0), not null
#  delivered_at          :datetime
#  delivery_method       :string           default("interactive"), not null
#  description           :string
#  enqueued_at           :datetime
#  error_code            :string
#  error_message         :text
#  failed_at             :datetime
#  message_content       :text             not null
#  meta_http_status      :integer
#  order_status          :string
#  payment_status        :string
#  payment_timestamp     :bigint
#  processing_started_at :datetime
#  read_at               :datetime
#  received_at           :datetime         not null
#  source                :string           default("external_api"), not null
#  status                :string           default("queued"), not null
#  template_components   :jsonb            not null
#  template_language     :string
#  template_name         :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  endpoint_id           :bigint           not null
#  inbox_id              :bigint           not null
#  meta_message_id       :string
#  order_id              :bigint           not null
#  requested_by_id       :bigint
#
# Indexes
#
#  idx_ibsoft_ext_order_updates_account_created               (account_id,created_at)
#  idx_ibsoft_ext_order_updates_dispatch                      (status,enqueued_at)
#  idx_ibsoft_ext_order_updates_endpoint                      (endpoint_id)
#  idx_ibsoft_ext_order_updates_meta_message                  (inbox_id,meta_message_id) UNIQUE WHERE (meta_message_id IS NOT NULL)
#  idx_ibsoft_ext_order_updates_order                         (order_id)
#  idx_ibsoft_ext_order_updates_queue                         (order_id,status,id)
#  idx_ibsoft_ext_order_updates_requested_by                  (requested_by_id)
#  index_ibsoft_external_message_order_updates_on_account_id  (account_id)
#  index_ibsoft_external_message_order_updates_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (endpoint_id => ibsoft_external_message_endpoints.id)
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#  fk_rails_...  (order_id => ibsoft_external_message_orders.id)
#  fk_rails_...  (requested_by_id => users.id)
#
class Ibsoft::ExternalMessaging::OrderUpdate < ApplicationRecord
  self.table_name = 'ibsoft_external_message_order_updates'

  STATUSES = %w[queued processing accepted sent delivered read failed uncertain unchanged].freeze
  ACTIVE_STATUSES = %w[queued processing].freeze
  BLOCKING_STATUSES = %w[processing uncertain].freeze
  SOURCES = %w[external_api manual].freeze
  DELIVERY_METHODS = %w[interactive template].freeze

  belongs_to :order,
             class_name: 'Ibsoft::ExternalMessaging::Order',
             inverse_of: :updates
  belongs_to :endpoint,
             class_name: 'Ibsoft::ExternalMessaging::Endpoint',
             inverse_of: :order_updates
  belongs_to :account
  belongs_to :inbox
  belongs_to :requested_by, class_name: 'User', optional: true

  validates :message_content, :received_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }
  validates :order_status,
            inclusion: { in: Ibsoft::ExternalMessaging::Order::ORDER_STATUSES },
            allow_nil: true
  validates :payment_status,
            inclusion: { in: Ibsoft::ExternalMessaging::Order::PAYMENT_STATUSES },
            allow_nil: true
  validates :payment_timestamp, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :requested_by, presence: true, if: :manual_source?
  validate :requested_status_present
  validate :tenant_matches_relations
  validate :delivery_snapshot_is_valid

  before_validation :normalize_delivery_snapshot

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def payload
    identity_payload.merge(
      requested_status_payload,
      delivery_status_payload,
      timestamp_payload
    )
  end

  def dashboard_payload
    {
      id: id,
      status: status,
      order_status: order_status,
      payment_status: payment_status,
      delivery_method: delivery_method,
      template_name: template_name,
      template_language: template_language,
      source: source,
      requested_by: requested_by&.name,
      created_at: created_at
    }
  end

  private

  def manual_source?
    source == 'manual'
  end

  def identity_payload
    {
      id: id,
      endpoint_id: endpoint_id,
      endpoint_name: endpoint.name,
      inbox_id: inbox_id,
      inbox_name: inbox.name,
      reference_id: order.reference_id
    }
  end

  def requested_status_payload
    {
      order_status: order_status,
      payment_status: payment_status,
      message_content: message_content,
      delivery_method: delivery_method,
      template_name: template_name,
      template_language: template_language
    }
  end

  def delivery_status_payload
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

  def requested_status_present
    return if order_status.present? || payment_status.present?

    errors.add(:base, :invalid)
  end

  def normalize_delivery_snapshot
    self.delivery_method = delivery_method.to_s.strip
    self.template_name = template_name.to_s.strip.presence
    self.template_language = template_language.to_s.strip.presence
    return unless template_components.is_a?(Array)

    self.template_components = template_components.map do |component|
      component.respond_to?(:to_h) ? component.to_h.deep_stringify_keys : component
    end
  end

  def delivery_snapshot_is_valid
    return errors.add(:template_components, :invalid) unless valid_template_components?

    delivery_method == 'template' ? validate_template_snapshot : validate_interactive_snapshot
  end

  def valid_template_components?
    template_components.is_a?(Array) && template_components.all?(Hash)
  end

  def validate_template_snapshot
    errors.add(:template_name, :blank) if template_name.blank?
    errors.add(:template_language, :blank) if template_language.blank?
  end

  def validate_interactive_snapshot
    return if template_name.blank? && template_language.blank? && template_components.empty?

    errors.add(:base, :invalid)
  end

  def tenant_matches_relations
    return if endpoint.blank? || order.blank?
    return if [endpoint.account_id, order.account_id].uniq == [account_id] &&
              [endpoint.inbox_id, order.inbox_id].uniq == [inbox_id]

    errors.add(:base, :invalid)
  end
end
