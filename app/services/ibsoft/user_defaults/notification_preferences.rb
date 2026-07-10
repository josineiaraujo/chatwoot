class Ibsoft::UserDefaults::NotificationPreferences
  PUSH_FLAGS = %i[
    push_conversation_assignment
    push_conversation_mention
    push_assigned_conversation_new_message
    push_participating_conversation_new_message
  ].freeze

  AUDIO_UI_SETTINGS = {
    'enable_audio_alerts' => 'assigned',
    'notification_tone' => 'magic',
    'always_play_audio_alert' => false,
    'alert_if_unread_assigned_conversation_exist' => false
  }.freeze

  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    ActiveRecord::Base.transaction do
      apply_notification_defaults!
      apply_audio_defaults!
    end
  end

  private

  def apply_notification_defaults!
    setting = user.notification_settings.find_or_initialize_by(account_id: account.id)
    return if setting.persisted?

    setting.selected_email_flags = []
    setting.selected_push_flags = valid_push_flags(setting)
    setting.save!
  end

  def valid_push_flags(setting)
    PUSH_FLAGS.select { |flag| setting.respond_to?("#{flag}?") }
  end

  def apply_audio_defaults!
    ui_settings = (user.ui_settings || {}).deep_stringify_keys
    missing_defaults = AUDIO_UI_SETTINGS.reject { |key, _value| ui_settings.key?(key) }
    return if missing_defaults.blank?

    user.update!(ui_settings: ui_settings.merge(missing_defaults))
  end
end
