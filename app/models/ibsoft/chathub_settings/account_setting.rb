# == Schema Information
#
# Table name: ibsoft_chathub_settings
#
#  id         :bigint           not null, primary key
#  config     :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_ibsoft_chathub_settings_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Ibsoft::ChathubSettings::AccountSetting < ApplicationRecord
  self.table_name = 'ibsoft_chathub_settings'

  DEFAULT_CONFIG = {
    'agent_entry_assignment' => {
      'enabled' => true,
      'required_percentage' => 20,
      'minimum_required' => 1,
      'block_close_when_required' => true
    },
    'login_stabilization' => {
      'enabled' => false,
      'offline_threshold_minutes' => 60,
      'window_minutes' => 10,
      'max_assignments_during_window' => 1,
      'minimum_online_agents_to_disable' => 2
    }
  }.freeze

  CONFIG_SECTIONS = {
    'agent_entry_assignment' => %w[
      enabled
      required_percentage
      minimum_required
      block_close_when_required
    ],
    'login_stabilization' => %w[
      enabled
      offline_threshold_minutes
      window_minutes
      max_assignments_during_window
      minimum_online_agents_to_disable
    ]
  }.freeze

  belongs_to :account

  before_validation :normalize_config
  validate :validate_config

  validates :account_id, uniqueness: true

  def self.default_config
    DEFAULT_CONFIG.deep_dup
  end

  def effective_config
    self.class.default_config.deep_merge(sanitized_config(config || {}))
  end

  def payload
    {
      id: id,
      account_id: account_id,
      config: effective_config,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def normalize_config
    self.config = self.class.default_config.deep_merge(sanitized_config(config || {}))
  end

  def validate_config
    Ibsoft::ChathubSettings::ConfigurationValidator.new(self).validate
  end

  def sanitized_config(raw_config)
    config_hash = (raw_config || {}).deep_stringify_keys

    CONFIG_SECTIONS.each_with_object({}) do |(section, keys), memo|
      section_config = config_hash.fetch(section, {}).slice(*keys)
      memo[section] = section_config if section_config.present?
    end
  end
end
