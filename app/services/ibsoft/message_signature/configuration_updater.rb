# frozen_string_literal: true

class Ibsoft::MessageSignature::ConfigurationUpdater
  class ValidationError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.to_s)
    end
  end

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def call
    enabled = resolved_enabled
    inbox_ids = resolved_inbox_ids

    raise ValidationError, :inbox_ids_required if enabled && inbox_ids.empty?

    validate_account_inboxes!(inbox_ids)
    persist!(enabled, inbox_ids)

    Ibsoft::MessageSignature::Configuration.new(account).payload
  end

  private

  attr_reader :account, :params

  def current_configuration
    @current_configuration ||= Ibsoft::MessageSignature::Configuration.new(account)
  end

  def resolved_enabled
    return current_configuration.enabled? unless params.key?(:enabled)

    ActiveModel::Type::Boolean.new.cast(params[:enabled])
  end

  def resolved_inbox_ids
    return current_configuration.inbox_ids unless params.key?(:inbox_ids)

    values = Array(params[:inbox_ids])
    ids = values.map { |value| Integer(value, exception: false) }
    raise ValidationError, :inbox_ids_invalid if ids.any?(&:nil?) || ids.any? { |id| !id.positive? }

    ids.uniq.sort
  end

  def validate_account_inboxes!(inbox_ids)
    existing_ids = account.inboxes.where(id: inbox_ids).pluck(:id)
    return if existing_ids.sort == inbox_ids

    raise ValidationError, :inbox_ids_not_found
  end

  def persist!(enabled, inbox_ids)
    account.with_lock do
      merged_settings = (account.settings || {}).deep_dup
      merged_settings[Ibsoft::MessageSignature::Configuration::SETTINGS_KEY] = {
        'enabled' => enabled,
        'inbox_ids' => inbox_ids
      }
      account.update!(settings: merged_settings)
    end
  end
end
