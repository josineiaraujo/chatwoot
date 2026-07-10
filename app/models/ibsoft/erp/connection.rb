# == Schema Information
#
# Table name: ibsoft_erp_connections
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(FALSE), not null
#  auth_type        :string           not null
#  base_url         :string           not null
#  credentials      :text             default({}), not null
#  last_test_status :string
#  last_tested_at   :datetime
#  name             :string           not null
#  provider         :string           not null
#  settings         :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  idx_ibsoft_erp_connections_account_provider_name  (account_id,provider,name) UNIQUE
#  idx_ibsoft_erp_connections_one_active             (account_id,active) UNIQUE WHERE (active = true)
#  index_ibsoft_erp_connections_on_account_id        (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Ibsoft::Erp::Connection < ApplicationRecord
  self.table_name = 'ibsoft_erp_connections'

  PROVIDER_LABELS = {
    'ixc' => 'IXC Provedor',
    'sgp' => 'SGP'
  }.freeze

  AUTH_TYPES_BY_PROVIDER = {
    'ixc' => %w[basic],
    'sgp' => %w[basic token_app]
  }.freeze

  CREDENTIAL_KEYS = {
    'basic' => %w[username password],
    'token_app' => %w[token app]
  }.freeze

  serialize :credentials, coder: JSON
  encrypts :credentials if Chatwoot.encryption_configured?

  belongs_to :account

  before_validation :normalize_attributes
  before_save :deactivate_other_connections, if: :active?

  validates :name, :provider, :auth_type, :base_url, presence: true
  validates :provider, inclusion: { in: PROVIDER_LABELS.keys }
  validate :auth_type_supported_by_provider
  validate :required_credentials_present

  def self.providers_payload
    PROVIDER_LABELS.map do |key, label|
      {
        key: key,
        label: label,
        auth_types: AUTH_TYPES_BY_PROVIDER.fetch(key)
      }
    end
  end

  def payload
    {
      id: id,
      account_id: account_id,
      name: name,
      provider: provider,
      provider_label: PROVIDER_LABELS[provider],
      auth_type: auth_type,
      base_url: base_url,
      active: active,
      settings: settings || {},
      credentials_configured: credentials_configured?,
      credential_keys: credential_keys,
      last_tested_at: last_tested_at,
      last_test_status: last_test_status,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def credential_keys
    CREDENTIAL_KEYS.fetch(auth_type, [])
  end

  def credentials_configured?
    normalized_credentials = credentials.to_h.with_indifferent_access

    credential_keys.all? { |key| normalized_credentials[key].present? }
  end

  private

  def normalize_attributes
    self.name = name.to_s.strip
    self.provider = provider.to_s.strip.downcase
    self.auth_type = auth_type.to_s.strip.downcase
    self.base_url = normalized_base_url
    self.credentials = normalize_hash(credentials)
    self.settings = normalize_hash(settings)
  end

  def normalized_base_url
    value = base_url.to_s.strip
    value.delete_suffix('/')
  end

  def normalize_hash(value)
    raw_value = value.is_a?(Hash) ? value : {}

    raw_value.deep_stringify_keys.transform_values do |item|
      item.is_a?(String) ? item.strip : item
    end
  end

  def auth_type_supported_by_provider
    return if provider.blank? || auth_type.blank?
    return if AUTH_TYPES_BY_PROVIDER.fetch(provider, []).include?(auth_type)

    errors.add(:auth_type, :invalid)
  end

  def required_credentials_present
    return if auth_type.blank?

    missing_keys = credential_keys.select { |key| credentials.to_h[key].blank? }
    return if missing_keys.empty?

    errors.add(:credentials, :blank)
  end

  def deactivate_other_connections
    self.class
        .where(account_id: account_id, active: true)
        .where.not(id: id)
        .find_each { |connection| connection.update!(active: false) }
  end
end
