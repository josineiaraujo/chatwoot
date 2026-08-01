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
#  inbox_id            :bigint           not null
#  opening_delivery_id :bigint           not null
#  reference_id        :string           not null
#
# Indexes
#
#  idx_ibsoft_ext_orders_account_status_created        (account_id,order_status,payment_status,created_at)
#  idx_ibsoft_ext_orders_opening_delivery              (opening_delivery_id) UNIQUE
#  idx_ibsoft_ext_orders_tenant_reference              (account_id,inbox_id,reference_id) UNIQUE
#  index_ibsoft_external_message_orders_on_account_id  (account_id)
#  index_ibsoft_external_message_orders_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (opening_delivery_id => ibsoft_external_message_deliveries.id)
#
class Ibsoft::ExternalMessaging::Order < ApplicationRecord
  self.table_name = 'ibsoft_external_message_orders'

  ORDER_STATUSES = %w[pending processing partially_shipped shipped completed canceled].freeze
  PAYMENT_STATUSES = %w[pending captured failed].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :opening_delivery,
             class_name: 'Ibsoft::ExternalMessaging::Delivery',
             inverse_of: :external_order
  has_many :updates,
           -> { order(:id) },
           class_name: 'Ibsoft::ExternalMessaging::OrderUpdate',
           inverse_of: :order,
           dependent: :restrict_with_error

  scope :manually_updateable, lambda {
    joins(:opening_delivery)
      .where(
        ibsoft_external_message_deliveries: {
          status: %w[accepted sent delivered read]
        }
      )
      .where.not(ibsoft_external_message_deliveries: { meta_message_id: nil })
      .where.not(
        id: Ibsoft::ExternalMessaging::OrderUpdate
            .where(status: 'uncertain')
            .select(:order_id)
      )
  }

  validates :reference_id, presence: true, uniqueness: { scope: [:account_id, :inbox_id] }
  validates :order_status, inclusion: { in: ORDER_STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }, allow_nil: true
  validate :tenant_matches_opening_delivery

  def ready_for_updates?
    opening_delivery.meta_message_id.present? &&
      opening_delivery.status.in?(%w[accepted sent delivered read])
  end

  def manually_updateable?
    ready_for_updates? && updates.none? { |update| update.status == 'uncertain' }
  end

  def dashboard_payload
    latest_update = updates.max_by(&:id)
    {
      id: id,
      endpoint_id: opening_delivery.endpoint_id,
      reference_id: reference_id,
      recipient: opening_delivery.recipient,
      template_name: opening_delivery.template_name,
      delivery_status: opening_delivery.status,
      order_status: order_status,
      payment_status: payment_status,
      manually_updateable: manually_updateable?,
      latest_update: latest_update&.dashboard_payload,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def tenant_matches_opening_delivery
    return if opening_delivery.blank?
    return if opening_delivery.account_id == account_id && opening_delivery.inbox_id == inbox_id

    errors.add(:opening_delivery, :invalid)
  end
end
