require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::UnavailabilityConfig do
  it 'returns the reason-specific configuration when present' do
    config = {
      unavailability: {
        no_available_agent: {
          action: 'notify_customer',
          message: 'Todos os atendentes estao ocupados.',
          fallback_team_id: nil
        },
        outside_business_hours: {
          action: 'fallback_team',
          message: nil,
          fallback_team_id: 12
        }
      },
      unavailable: {
        action: 'wait',
        message: nil,
        fallback_team_id: nil
      }
    }

    result = described_class.for(config, 'outside_business_hours')

    expect(result).to include(
      'action' => 'fallback_team',
      'message' => nil,
      'fallback_team_id' => 12
    )
  end

  it 'falls back to the legacy unavailable configuration' do
    config = {
      unavailable: {
        action: 'notify_customer',
        message: 'Aguarde um atendente.',
        fallback_team_id: nil
      }
    }

    result = described_class.for(config, 'no_available_agent')

    expect(result).to include(
      'action' => 'notify_customer',
      'message' => 'Aguarde um atendente.',
      'fallback_team_id' => nil
    )
  end

  it 'uses a safe wait decision when nothing is configured' do
    result = described_class.for({}, 'no_available_agent')

    expect(result).to include(
      'action' => 'wait',
      'message' => nil,
      'fallback_team_id' => nil
    )
  end
end
