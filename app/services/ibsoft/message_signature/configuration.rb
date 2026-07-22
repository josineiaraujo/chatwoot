# frozen_string_literal: true

class Ibsoft::MessageSignature::Configuration
  SETTINGS_KEY = 'ibsoft_message_signature'

  def initialize(account)
    @account = account
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(settings.fetch('enabled', false)) == true
  end

  def inbox_ids
    Array(settings['inbox_ids']).filter_map do |value|
      Integer(value, exception: false)
    end.select(&:positive?).uniq.sort
  end

  def enabled_for_inbox?(inbox_id)
    enabled? && inbox_ids.include?(inbox_id.to_i)
  end

  def payload
    {
      enabled: enabled?,
      inbox_ids: inbox_ids
    }
  end

  private

  attr_reader :account

  def settings
    raw_settings = account.settings || {}
    value = raw_settings[SETTINGS_KEY] || raw_settings[SETTINGS_KEY.to_sym]

    value.is_a?(Hash) ? value.stringify_keys : {}
  end
end
