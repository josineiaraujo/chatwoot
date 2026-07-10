require 'rails_helper'

RSpec.describe Ibsoft::UserDefaults::NotificationPreferences do
  let(:account) { create(:account) }
  let(:user) { create(:user) }

  describe '#perform' do
    it 'creates notification settings with Ibsoft push defaults and email disabled' do
      described_class.new(account: account, user: user).perform

      setting = user.notification_settings.find_by!(account_id: account.id)

      expect(setting.selected_email_flags).to eq([])
      expect(setting.selected_push_flags).to match_array(
        %i[
          push_conversation_assignment
          push_conversation_mention
          push_assigned_conversation_new_message
          push_participating_conversation_new_message
        ]
      )
    end

    it 'ignores configured push flags that are not supported by the current Chatwoot version' do
      stub_const("#{described_class}::PUSH_FLAGS", described_class::PUSH_FLAGS + [:push_future_chatwoot_flag])

      expect do
        described_class.new(account: account, user: user).perform
      end.not_to raise_error

      setting = user.notification_settings.find_by!(account_id: account.id)

      expect(setting.selected_push_flags).not_to include(:push_future_chatwoot_flag)
    end

    it 'sets audio defaults without overriding existing user preferences' do
      user.update!(
        ui_settings: {
          'notification_tone' => 'bell',
          'locale' => 'pt_BR'
        }
      )

      described_class.new(account: account, user: user).perform

      expect(user.reload.ui_settings).to include(
        'enable_audio_alerts' => 'assigned',
        'notification_tone' => 'bell',
        'always_play_audio_alert' => false,
        'alert_if_unread_assigned_conversation_exist' => false,
        'locale' => 'pt_BR'
      )
    end

    it 'does not overwrite an existing account notification setting' do
      setting = NotificationSetting.new(account: account, user: user)
      setting.selected_email_flags = [:email_conversation_creation]
      setting.selected_push_flags = [:push_conversation_creation]
      setting.save!

      described_class.new(account: account, user: user).perform

      setting.reload
      expect(setting.selected_email_flags).to eq([:email_conversation_creation])
      expect(setting.selected_push_flags).to eq([:push_conversation_creation])
    end
  end
end
