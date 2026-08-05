# == Schema Information
#
# Table name: ibsoft_external_message_orders
#
#  id                  :bigint           not null, primary key
#  order_status        :string           default("pending"), not null
#  payment_status      :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  endpoint_id         :bigint           not null
#  inbox_id            :bigint           not null
#  opening_delivery_id :bigint           not null
#  reference_id        :string           not null
#
# Indexes
#
#  idx_ibsoft_ext_orders_account_status_created        (account_id,order_status,payment_status,created_at)
#  idx_ibsoft_ext_orders_endpoint_reference            (endpoint_id,reference_id) UNIQUE
#  idx_ibsoft_ext_orders_opening_delivery              (opening_delivery_id) UNIQUE
#  index_ibsoft_external_message_orders_on_account_id  (account_id)
#  index_ibsoft_external_message_orders_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (endpoint_id => ibsoft_external_message_endpoints.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (opening_delivery_id => ibsoft_external_message_deliveries.id)
#
class Ibsoft::ExternalMessaging::Order < ApplicationRecord
  self.table_name = 'ibsoft_external_message_orders'

  ORDER_STATUSES = %w[pending processing partially_shipped shipped completed canceled].freeze
  PAYMENT_STATUSES = %w[pending captured failed].freeze
  SUCCESSFUL_DELIVERY_STATUSES = %w[accepted sent delivered read].freeze
  FINAL_ORDER_STATUSES = %w[completed canceled].freeze

  belongs_to :endpoint,
             class_name: 'Ibsoft::ExternalMessaging::Endpoint',
             inverse_of: :orders
  belongs_to :account
  belongs_to :inbox
  belongs_to :opening_delivery,
             class_name: 'Ibsoft::ExternalMessaging::Delivery',
             inverse_of: :opened_external_order
  has_many :deliveries,
           -> { order(:id) },
           class_name: 'Ibsoft::ExternalMessaging::Delivery',
           foreign_key: :order_id,
           inverse_of: :external_order,
           dependent: :nullify
  has_many :updates,
           -> { order(:id) },
           class_name: 'Ibsoft::ExternalMessaging::OrderUpdate',
           inverse_of: :order,
           dependent: :restrict_with_error

  scope :manually_updateable, lambda {
    joins(:deliveries)
      .where(
        ibsoft_external_message_deliveries: {
          status: SUCCESSFUL_DELIVERY_STATUSES
        }
      )
      .where.not(ibsoft_external_message_deliveries: { meta_message_id: nil })
      .where.not(
        id: Ibsoft::ExternalMessaging::OrderUpdate
            .where(status: 'uncertain')
            .select(:order_id)
      )
      .distinct
  }

  validates :reference_id, presence: true, uniqueness: { scope: :endpoint_id }
  validates :order_status, inclusion: { in: ORDER_STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }, allow_nil: true
  validate :tenant_matches_opening_delivery

  def ready_for_updates?
    if deliveries.loaded?
      deliveries.any? do |delivery|
        delivery.meta_message_id.present? && delivery.status.in?(SUCCESSFUL_DELIVERY_STATUSES)
      end
    else
      deliveries
        .where(status: SUCCESSFUL_DELIVERY_STATUSES)
        .where.not(meta_message_id: nil)
        .exists?
    end
  end

  def manually_updateable?
    ready_for_updates? && updates.none? { |update| update.status == 'uncertain' }
  end

  def finalized_for_resend?
    payment_status == 'captured' || order_status.in?(FINAL_ORDER_STATUSES)
  end

  def recipient
    opening_delivery.recipient
  end

  def dashboard_payload
    latest_update = updates.max_by(&:id)
    display_delivery = latest_delivery
    {
      id: id,
      endpoint_id: endpoint_id,
      reference_id: reference_id,
      recipient: recipient,
      template_name: display_delivery.template_name,
      delivery_status: display_delivery.status,
      order_status: order_status,
      payment_status: payment_status,
      manually_updateable: manually_updateable?,
      latest_update: latest_update&.dashboard_payload,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def latest_delivery
    return deliveries.max_by(&:id) || opening_delivery if deliveries.loaded?

    deliveries.order(id: :desc).first || opening_delivery
  end

  def tenant_matches_opening_delivery
    return if opening_delivery.blank? || endpoint.blank?
    return if opening_delivery.endpoint_id == endpoint_id &&
              opening_delivery.account_id == account_id &&
              opening_delivery.inbox_id == inbox_id &&
              opening_delivery.order_reference_id == reference_id

    errors.add(:opening_delivery, :invalid)
  end
end
