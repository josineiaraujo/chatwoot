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
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       business_hours: {
                                                         mode: 'custom',
                                                         timezone: 'America/Sao_Paulo',
                                                         schedule: [{ day_of_week: 3, closed_all_day: true }]
                                                       },
                                                       unavailability: {
                                                         no_available_agent: {
                                                           action: 'fallback_team',
                                                           fallback_team_id: create(:team, account: account).id
                                                         },
                                                         outside_business_hours: {
                                                           action: 'notify_customer',
                                                           message: 'Estamos fora do horario de atendimento.'
                                                         }
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

  it 'waits while a custom team schedule is inside a configured break' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       business_hours: {
                                                         mode: 'custom',
                                                         timezone: 'America/Sao_Paulo',
                                                         schedule: [
                                                           {
                                                             day_of_week: 3,
                                                             closed_all_day: false,
                                                             open_all_day: false,
                                                             open_hour: 9,
                                                             open_minutes: 0,
                                                             close_hour: 17,
                                                             close_minutes: 0
                                                           }
                                                         ],
                                                         breaks: [
                                                           {
                                                             day_of_week: 3,
                                                             start_hour: 12,
                                                             start_minutes: 0,
                                                             end_hour: 13,
                                                             end_minutes: 0
                                                           }
                                                         ]
                                                       }
                                                     }
                                                   )

    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 12:30:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'wait',
      reason: 'outside_business_hours',
      unavailable_action: 'wait',
      within_business_hours: false
    )
  end

  it 'allows assignment after a custom team schedule break ends' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       business_hours: {
                                                         mode: 'custom',
                                                         timezone: 'America/Sao_Paulo',
                                                         schedule: [
                                                           {
                                                             day_of_week: 3,
                                                             closed_all_day: false,
                                                             open_all_day: false,
                                                             open_hour: 9,
                                                             open_minutes: 0,
                                                             close_hour: 17,
                                                             close_minutes: 0
                                                           }
                                                         ],
                                                         breaks: [
                                                           {
                                                             day_of_week: 3,
                                                             start_hour: 12,
                                                             start_minutes: 0,
                                                             end_hour: 13,
                                                             end_minutes: 0
                                                           }
                                                         ]
                                                       }
                                                     }
                                                   )

    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 13:00:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'assign',
      reason: 'eligible_for_assignment',
      within_business_hours: true
    )
  end

  it 'treats a linked holiday as outside business hours even when the policy is always available' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account)
    distribution_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                                         .distribution_policy
    distribution_policy.update!(
      after_hours_policy: after_hours_policy,
      config: {
        business_hours: { mode: 'always_available' },
        unavailability: {
          outside_business_hours: { action: 'after_hours_policy' }
        }
      }
    )
    calendar = create(:ibsoft_business_calendar, account: account)
    create(:ibsoft_business_calendar_team_link, account: account, team: team, business_calendar: calendar)
    holiday = create(
      :ibsoft_business_holiday,
      business_calendar: calendar,
      holiday_date: Date.new(2026, 7, 1),
      name: 'Feriado estadual'
    )
    Rails.cache.clear

    now = ActiveSupport::TimeZone[inbox.timezone].parse('2026-07-01 10:00:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'after_hours_policy',
      reason: 'outside_business_hours',
      unavailable_action: 'after_hours_policy',
      within_business_hours: false,
      outside_business_hours_cause: 'holiday',
      business_calendar_id: calendar.id,
      business_holiday_id: holiday.id,
      holiday_name: 'Feriado estadual',
      holiday_date: '2026-07-01',
      after_hours_policy_id: after_hours_policy.id,
      after_hours_policy_name: after_hours_policy.name
    )
  end

  it 'uses the regular after-hours policy when the schedule is closed without a holiday' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account)
    distribution_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                                         .distribution_policy
    distribution_policy.update!(
      after_hours_policy: after_hours_policy,
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: [{ day_of_week: 3, closed_all_day: true }]
        },
        unavailability: {
          outside_business_hours: { action: 'after_hours_policy' }
        }
      }
    )

    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 10:00:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'after_hours_policy',
      reason: 'outside_business_hours',
      within_business_hours: false,
      outside_business_hours_cause: 'schedule',
      after_hours_policy_id: after_hours_policy.id
    )
    expect(decision).not_to include(:business_holiday_id)
  end

  it 'waits safely when the linked after-hours policy is disabled' do
    after_hours_policy = create(:ibsoft_after_hours_policy, account: account, enabled: false)
    distribution_policy = Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                                         .distribution_policy
    distribution_policy.update!(
      after_hours_policy: after_hours_policy,
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: [{ day_of_week: 3, closed_all_day: true }]
        },
        unavailability: {
          outside_business_hours: { action: 'after_hours_policy' }
        }
      }
    )

    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-07-01 10:00:00')
    decision = described_class.new(conversation: conversation, candidate: candidate, now: now).perform

    expect(decision).to include(
      action: 'wait',
      reason: 'outside_business_hours',
      unavailable_action: 'after_hours_policy',
      after_hours_policy_id: after_hours_policy.id
    )
  end

  it 'uses the no available agent fallback without applying the outside-hours rule' do
    fallback_team = create(:team, account: account)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       unavailability: {
                                                         no_available_agent: {
                                                           action: 'fallback_team',
                                                           fallback_team_id: fallback_team.id
                                                         },
                                                         outside_business_hours: {
                                                           action: 'notify_customer',
                                                           message: 'Estamos fora do horario.'
                                                         }
                                                       }
                                                     }
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

  it 'keeps legacy unavailable behavior for policies saved before reason-specific configuration' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
                                                     config: {
                                                       unavailable: {
                                                         action: 'notify_customer',
                                                         message: 'Aguarde um atendente ficar disponivel.'
                                                       }
                                                     }
                                                   )

    decision = described_class.new(conversation: conversation, candidate: candidate).unavailable_decision

    expect(decision).to include(
      action: 'notify_customer',
      reason: 'no_available_agent',
      unavailable_action: 'notify_customer',
      message_present: true
    )
  end

  it 'uses fallback team decision when no agent is available and fallback is configured' do
    fallback_team = create(:team, account: account)
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(
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
