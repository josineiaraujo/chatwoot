require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::DecisionResolver do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team, waiting_since: 10.minutes.ago) }
  let(:candidate) { { eligible: true, reasons: [] } }

  before do
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)
  end

  it 'allows assignment for an eligible candidate inside business hours' do
    decision = described_class.new(conversation: conversation, candidate: candidate).perform

    expect(decision).to include(
      action: 'assign',
      reason: 'eligible_for_assignment',
      business_hours_mode: 'inherit_channel',
      within_business_hours: true
    )
  end

  it 'skips candidates already marked as ineligible' do
    candidate[:eligible] = false
    candidate[:reasons] = ['source_not_allowed']

    decision = described_class.new(conversation: conversation, candidate: candidate).perform

    expect(decision).to include(
      action: 'skip',
      reason: 'not_eligible',
      candidate_reasons: ['source_not_allowed']
    )
  end

  it 'waits when inheriting a closed communication channel schedule' do
    travel_to Time.zone.parse('2026-07-01 10:00:00') do
      inbox.update!(working_hours_enabled: true)
      inbox.working_hours.find_by!(day_of_week: Time.current.in_time_zone(inbox.timezone).wday).update!(
        closed_all_day: true,
        open_all_day: false
      )

      decision = described_class.new(conversation: conversation, candidate: candidate).perform

      expect(decision).to include(
        action: 'wait',
        reason: 'outside_business_hours',
        unavailable_action: 'wait',
        within_business_hours: false
      )
    end
  end

  it 'uses notify customer decision for a closed custom schedule' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox).update!(
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: [{ day_of_week: 3, closed_all_day: true }]
        },
        unavailable: {
          action: 'notify_customer',
          message: 'Aguarde um atendente ficar disponivel.'
        }
      }
    )

    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 10:00:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'notify_customer',
      reason: 'outside_business_hours',
      unavailable_action: 'notify_customer',
      message_present: true,
      within_business_hours: false
    )
  end

  it 'uses fallback team decision when no agent is available and fallback is configured' do
    fallback_team = create(:team, account: account)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox).update!(
      config: { unavailable: { action: 'fallback_team', fallback_team_id: fallback_team.id } }
    )

    decision = described_class.new(conversation: conversation, candidate: candidate).unavailable_decision

    expect(decision).to include(
      action: 'fallback_team',
      reason: 'no_available_agent',
      unavailable_action: 'fallback_team',
      fallback_team_id: fallback_team.id,
      fallback_team_configured: true
    )
  end
end
