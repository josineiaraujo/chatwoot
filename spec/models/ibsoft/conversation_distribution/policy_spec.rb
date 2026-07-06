require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::Policy do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:valid_schedule) do
    [
      {
        day_of_week: 1,
        closed_all_day: false,
        open_all_day: false,
        open_hour: 9,
        open_minutes: 0,
        close_hour: 17,
        close_minutes: 0
      }
    ]
  end

  it 'normalizes config and exposes linked counters' do
    policy = described_class.create!(
      account: account,
      name: 'Comercial padrao',
      enabled: true,
      config: { distribution: { max_assignments_per_round: 3 } }
    )

    expect(policy.effective_config.dig('distribution', 'max_assignments_per_round')).to eq(3)
    expect(policy.effective_config.dig('distribution', 'max_assignments_per_round_enabled')).to be(true)
    expect(policy.effective_config.dig('distribution', 'assignment_order')).to eq('round_robin')
    expect(policy.effective_config.dig('distribution', 'conversation_priority')).to eq('longest_waiting')
    expect(policy.effective_config.dig('distribution', 'fair_distribution_limit')).to eq(100)
    expect(policy.effective_config.dig('distribution', 'fair_distribution_window')).to eq(3600)
    expect(policy.payload).to include(
      name: 'Comercial padrao',
      enabled: true,
      linked_channels_count: 0,
      linked_teams_count: 0,
      policy_type: 'named'
    )
  end

  it 'normalizes assignment confirmation defaults' do
    policy = described_class.create!(
      account: account,
      name: 'Comercial confirmacao',
      enabled: true,
      config: {}
    )

    expect(policy.effective_config.dig('assignment_confirmation', 'enabled')).to be(false)
    expect(policy.effective_config.dig('assignment_confirmation', 'only_before_first_reply')).to be(true)
  end

  it 'normalizes unavailability defaults for both reasons' do
    policy = described_class.create!(
      account: account,
      name: 'Comercial disponibilidade',
      enabled: true,
      config: {}
    )

    expect(policy.effective_config.dig('unavailability', 'no_available_agent', 'action')).to eq('wait')
    expect(policy.effective_config.dig('unavailability', 'outside_business_hours', 'action')).to eq('wait')
  end

  it 'normalizes simultaneous capacity defaults' do
    policy = described_class.create!(
      account: account,
      name: 'Comercial capacidade',
      enabled: true,
      config: { distribution: { max_assignments_per_round: 3 } }
    )

    expect(policy.effective_config.dig('distribution', 'assignment_limit_mode')).to eq('open_conversations')
    expect(policy.effective_config.dig('distribution', 'open_conversation_limit')).to eq(5)
    expect(policy.effective_config.dig('distribution', 'capacity_excluded_labels')).to eq([])
  end

  it 'normalizes business hour break defaults' do
    policy = described_class.create!(
      account: account,
      name: 'Comercial intervalos',
      enabled: true,
      config: {}
    )

    expect(policy.effective_config.dig('business_hours', 'breaks')).to eq([])
  end

  it 'keeps legacy unavailable configuration compatible with both unavailable reasons' do
    policy = described_class.create!(
      account: account,
      name: 'Compatibilidade',
      enabled: true,
      config: {
        unavailable: {
          action: 'notify_customer',
          message: 'Aguarde um atendente.',
          fallback_team_id: nil
        }
      }
    )

    expect(policy.effective_config.dig('unavailability', 'no_available_agent')).to include(
      'action' => 'notify_customer',
      'message' => 'Aguarde um atendente.'
    )
    expect(policy.effective_config.dig('unavailability', 'outside_business_hours')).to include(
      'action' => 'notify_customer',
      'message' => 'Aguarde um atendente.'
    )
  end

  it 'keeps separate unavailability reasons when the new configuration is present' do
    policy = described_class.create!(
      account: account,
      name: 'Motivos separados',
      enabled: true,
      config: {
        unavailable: {
          action: 'notify_customer',
          message: 'Legado ignorado.',
          fallback_team_id: nil
        },
        unavailability: {
          no_available_agent: {
            action: 'notify_customer',
            message: 'Todos os atendentes estao ocupados.',
            fallback_team_id: nil
          },
          outside_business_hours: {
            action: 'wait',
            message: nil,
            fallback_team_id: nil
          }
        }
      }
    )

    expect(policy.effective_config.dig('unavailability', 'no_available_agent')).to include(
      'action' => 'notify_customer',
      'message' => 'Todos os atendentes estao ocupados.'
    )
    expect(policy.effective_config.dig('unavailability', 'outside_business_hours')).to include(
      'action' => 'wait',
      'message' => nil
    )
    expect(policy.effective_config.dig('unavailable', 'action')).to eq('wait')
  end

  it 'requires unique names per account' do
    create(:ibsoft_distribution_policy, account: account, name: 'Suporte')
    duplicate = build(:ibsoft_distribution_policy, account: account, name: 'Suporte')

    expect(duplicate).not_to be_valid
  end

  it 'rejects invalid assignment limit modes' do
    policy = described_class.new(
      account: account,
      name: 'Modo invalido',
      config: { distribution: { assignment_limit_mode: 'invalid' } }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('distribution.assignment_limit_mode is invalid')
  end

  it 'rejects enabled assignment confirmation without a message' do
    policy = described_class.new(
      account: account,
      name: 'Confirmacao sem mensagem',
      config: {
        assignment_confirmation: {
          enabled: true,
          message: ''
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('assignment_confirmation.message is required when enabled')
  end

  it 'rejects invalid fallback actions' do
    policy = described_class.new(
      account: account,
      name: 'Politica invalida',
      config: { unavailable: { action: 'invalid' } }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('has invalid unavailable action')
  end

  it 'rejects notify customer action without a message' do
    policy = described_class.new(
      account: account,
      name: 'Sem mensagem',
      config: { unavailable: { action: 'notify_customer', message: '' } }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('unavailable.message is required when action is notify_customer')
  end

  it 'rejects fallback teams outside the account' do
    other_team = create(:team)
    policy = described_class.new(
      account: account,
      name: 'Fallback externo',
      config: {
        unavailable: { action: 'fallback_team', fallback_team_id: other_team.id }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('unavailable.fallback_team_id must belong to account')
  end

  it 'accepts fallback teams from the same account' do
    policy = described_class.new(
      account: account,
      name: 'Fallback interno',
      config: {
        unavailable: { action: 'fallback_team', fallback_team_id: team.id }
      }
    )

    expect(policy).to be_valid
  end

  it 'rejects invalid reason-specific unavailable actions' do
    policy = described_class.new(
      account: account,
      name: 'Motivo invalido',
      config: {
        unavailability: {
          no_available_agent: { action: 'invalid' }
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('unavailability.no_available_agent.action is invalid')
  end

  it 'rejects reason-specific notify customer action without a message' do
    policy = described_class.new(
      account: account,
      name: 'Sem mensagem por motivo',
      config: {
        unavailability: {
          outside_business_hours: { action: 'notify_customer', message: '' }
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('unavailability.outside_business_hours.message is required when action is notify_customer')
  end

  it 'rejects reason-specific fallback teams outside the account' do
    other_team = create(:team)
    policy = described_class.new(
      account: account,
      name: 'Fallback externo por motivo',
      config: {
        unavailability: {
          no_available_agent: { action: 'fallback_team', fallback_team_id: other_team.id }
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('unavailability.no_available_agent.fallback_team_id must belong to account')
  end

  it 'rejects custom business hours without a valid timezone and schedule' do
    policy = described_class.new(
      account: account,
      name: 'Horario invalido',
      config: {
        business_hours: { mode: 'custom', timezone: 'Invalid/Zone', schedule: [] }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('business_hours.timezone must be valid')
    expect(policy.errors[:config]).to include('business_hours.schedule must be present')
  end

  it 'rejects custom business hours with invalid time windows' do
    policy = described_class.new(
      account: account,
      name: 'Janela invalida',
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: [
            {
              day_of_week: 1,
              closed_all_day: false,
              open_all_day: false,
              open_hour: 17,
              open_minutes: 0,
              close_hour: 9,
              close_minutes: 0
            }
          ]
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('business_hours.schedule close time must be after open time')
  end

  it 'accepts custom business hours with a valid weekly schedule' do
    policy = described_class.new(
      account: account,
      name: 'Horario valido',
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: valid_schedule
        }
      }
    )

    expect(policy).to be_valid
  end

  it 'accepts custom business hours with valid breaks' do
    policy = described_class.new(
      account: account,
      name: 'Horario com intervalo',
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: valid_schedule,
          breaks: [
            {
              day_of_week: 1,
              start_hour: 12,
              start_minutes: 0,
              end_hour: 13,
              end_minutes: 0
            }
          ]
        }
      }
    )

    expect(policy).to be_valid
  end

  it 'rejects custom business hours with invalid breaks' do
    policy = described_class.new(
      account: account,
      name: 'Intervalo invalido',
      config: {
        business_hours: {
          mode: 'custom',
          timezone: 'America/Sao_Paulo',
          schedule: valid_schedule,
          breaks: [
            {
              day_of_week: 1,
              start_hour: 13,
              start_minutes: 0,
              end_hour: 12,
              end_minutes: 0
            }
          ]
        }
      }
    )

    expect(policy).not_to be_valid
    expect(policy.errors[:config]).to include('business_hours.breaks end time must be after start time')
  end
end
