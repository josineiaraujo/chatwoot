# == Schema Information
#
# Table name: ibsoft_external_message_endpoints
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  instance_type           :string           default("sgp_generic"), not null
#  name                    :string           not null
#  order_pix_key           :text
#  order_pix_key_type      :string
#  order_pix_merchant_name :string
#  order_update_messages   :jsonb            not null
#  rate_limit_per_second   :integer          default(10), not null
#  retention_days          :integer          default(30), not null
#  token_digest            :string           not null
#  token_hint              :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  created_by_id           :bigint           not null
#  inbox_id                :bigint           not null
#
# Indexes
#
#  idx_ibsoft_external_endpoints_account_name                (account_id,name) UNIQUE
#  idx_ibsoft_external_endpoints_token                       (token_digest) UNIQUE
#  index_ibsoft_external_message_endpoints_on_account_id     (account_id)
#  index_ibsoft_external_message_endpoints_on_created_by_id  (created_by_id)
#  index_ibsoft_external_message_endpoints_on_inbox_id       (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
require 'digest'

class Ibsoft::ExternalMessaging::Endpoint < ApplicationRecord
  self.table_name = 'ibsoft_external_message_endpoints'

  TOKEN_PREFIX = 'ibext_'.freeze
  TOKEN_BYTES = 32
  INSTANCE_TYPES = Ibsoft::ExternalMessaging::InstanceTypeRegistry.keys.freeze
  PIX_KEY_TYPES = Ibsoft::ExternalMessaging::OrderPaymentSettingsBuilder::PIX_KEY_TYPES
  ORDER_UPDATE_MESSAGE_KEYS = Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog::KEYS

  encrypts :order_pix_key if Chatwoot.encryption_configured?

  belongs_to :account
  belongs_to :inbox
  belongs_to :created_by, class_name: 'User'
  has_many :deliveries,
           class_name: 'Ibsoft::ExternalMessaging::Delivery',
           inverse_of: :endpoint,
           dependent: :restrict_with_error
  has_many :order_updates,
           class_name: 'Ibsoft::ExternalMessaging::OrderUpdate',
           inverse_of: :endpoint,
           dependent: :restrict_with_error

  validates :name, :token_digest, :token_hint, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :instance_type, inclusion: { in: INSTANCE_TYPES }
  validates :rate_limit_per_second, numericality: { only_integer: true, in: 1..80 }
  validates :retention_days, numericality: { only_integer: true, in: 1..3650 }
  validates :order_pix_merchant_name, length: { maximum: 100 }, allow_blank: true
  validates :order_pix_key, length: { maximum: 255 }, allow_blank: true
  validates :order_pix_key_type, inclusion: { in: PIX_KEY_TYPES }, allow_blank: true
  validate :inbox_belongs_to_account
  validate :whatsapp_cloud_inbox
  validate :order_pix_key_encryption_available
  validate :order_update_messages_are_valid

  before_validation :normalize_attributes

  scope :active, -> { where(active: true) }

  def self.authenticate(raw_token)
    token = raw_token.to_s.strip
    return if token.blank?

    active.find_by(token_digest: digest_token(token))
  end

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token)
  end

  def issue_token
    raw_token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(TOKEN_BYTES)}"
    self.token_digest = self.class.digest_token(raw_token)
    self.token_hint = "#{raw_token.first(12)}..."
    raw_token
  end

  def rotate_token!
    raw_token = issue_token
    save!
    raw_token
  end

  def payload(deliveries_count: nil)
    {
      id: id,
      account_id: account_id,
      inbox_id: inbox_id,
      inbox_name: inbox.name,
      name: name,
      instance_type: instance_type,
      integration_family: instance_type_definition.family,
      public_path: instance_type_definition.public_path,
      order_update_path: instance_type_definition.order_update_path,
      token_hint: token_hint,
      authentication: Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: self).public_payload,
      active: active,
      rate_limit_per_second: rate_limit_per_second,
      deliveries_count: deliveries_count || deliveries.count,
      retention_days: retention_days,
      order_defaults: order_defaults_payload,
      order_defaults_configured: order_defaults_configured?
    }.merge(timestamp_payload)
  end

  def order_defaults_configured?
    order_pix_merchant_name.present? && order_pix_key.present? && order_pix_key_type.present?
  end

  def order_defaults_payload
    message_catalog = Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog.new(endpoint: self)
    {
      merchant_name: order_pix_merchant_name,
      key_type: order_pix_key_type,
      key_configured: order_pix_key.present?,
      key_hint: masked_order_pix_key,
      messages: message_catalog.effective,
      message_defaults: message_catalog.defaults
    }
  end

  def effective_rate_limit_per_second
    self.class.active
        .where(inbox_id: inbox_id)
        .minimum(:rate_limit_per_second) || rate_limit_per_second
  end

  private

  def timestamp_payload
    {
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def instance_type_definition
    Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(instance_type)
  end

  def normalize_attributes
    self.name = name.to_s.strip
    self.order_pix_merchant_name = order_pix_merchant_name.to_s.strip.presence
    self.order_pix_key = order_pix_key.to_s.strip.presence
    self.order_pix_key_type = order_pix_key_type.to_s.strip.upcase.presence
    normalize_order_update_messages
  end

  def normalize_order_update_messages
    return unless order_update_messages.is_a?(Hash)

    self.order_update_messages = order_update_messages.to_h.each_with_object({}) do |(key, value), result|
      normalized = value.to_s.strip
      result[key.to_s] = normalized if normalized.present?
    end
  end

  def masked_order_pix_key
    return if order_pix_key.blank?

    "****#{order_pix_key.last(4)}"
  end

  def order_pix_key_encryption_available
    return if order_pix_key.blank? || !Rails.env.production? || Chatwoot.encryption_configured?

    errors.add(:order_pix_key, :encryption_not_configured)
  end

  def order_update_messages_are_valid
    unless order_update_messages.is_a?(Hash)
      errors.add(:order_update_messages, :invalid)
      return
    end

    errors.add(:order_update_messages, :invalid) if (order_update_messages.keys - ORDER_UPDATE_MESSAGE_KEYS).any?
    return unless order_update_messages.values.any? do |message|
      message.to_s.bytesize > Ibsoft::ExternalMessaging::OrderUpdateMessageCatalog::MAX_MESSAGE_BYTES
    end

    errors.add(:order_update_messages, :too_long)
  end

  def inbox_belongs_to_account
    return if inbox.blank? || account.blank? || inbox.account_id == account_id

    errors.add(:inbox, :invalid)
  end

  def whatsapp_cloud_inbox
    return if inbox.blank?
    return if inbox.channel_type == 'Channel::Whatsapp' && inbox.channel&.provider == 'whatsapp_cloud'

    errors.add(:inbox, :invalid)
  end
end
