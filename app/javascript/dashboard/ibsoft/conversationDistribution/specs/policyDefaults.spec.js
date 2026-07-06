import { describe, expect, it } from 'vitest';

import { normalizePolicyConfig } from '../policyDefaults';

describe('#normalizePolicyConfig', () => {
  it('sets simultaneous open conversation capacity as the default limit mode', () => {
    const config = normalizePolicyConfig({
      distribution: {
        max_assignments_per_round: 3,
      },
    });

    expect(config.distribution).toMatchObject({
      max_assignments_per_round: 3,
      assignment_limit_mode: 'open_conversations',
      open_conversation_limit: 5,
      capacity_ignore_customer_waiting_enabled: false,
      capacity_ignore_customer_waiting_minutes: 1440,
      capacity_excluded_labels: [],
      fair_distribution_limit: 100,
      fair_distribution_window: 3600,
    });
    expect(config.assignment_confirmation).toMatchObject({
      enabled: false,
      message: null,
      only_before_first_reply: true,
    });
    expect(config.business_hours.breaks).toEqual([]);
  });

  it('copies legacy unavailable config to both unavailable reasons', () => {
    const config = normalizePolicyConfig({
      unavailable: {
        action: 'notify_customer',
        message: 'Aguarde um atendente.',
        fallback_team_id: null,
      },
    });

    expect(config.unavailability.no_available_agent).toMatchObject({
      action: 'notify_customer',
      message: 'Aguarde um atendente.',
      fallback_team_id: null,
    });
    expect(config.unavailability.outside_business_hours).toMatchObject({
      action: 'notify_customer',
      message: 'Aguarde um atendente.',
      fallback_team_id: null,
    });
  });

  it('keeps reason-specific unavailable config isolated from legacy values', () => {
    const config = normalizePolicyConfig({
      unavailable: {
        action: 'notify_customer',
        message: 'Legado ignorado.',
        fallback_team_id: null,
      },
      unavailability: {
        no_available_agent: {
          action: 'fallback_team',
          fallback_team_id: 12,
        },
        outside_business_hours: {
          action: 'notify_customer',
          message: 'Estamos fora do horario.',
        },
      },
    });

    expect(config.unavailable).toMatchObject({
      action: 'wait',
      message: null,
      fallback_team_id: null,
    });
    expect(config.unavailability.no_available_agent).toMatchObject({
      action: 'fallback_team',
      fallback_team_id: 12,
    });
    expect(config.unavailability.outside_business_hours).toMatchObject({
      action: 'notify_customer',
      message: 'Estamos fora do horario.',
    });
  });

  it('keeps custom business hour breaks while normalizing policies', () => {
    const config = normalizePolicyConfig({
      business_hours: {
        mode: 'custom',
        timezone: 'America/Sao_Paulo',
        breaks: [
          {
            day_of_week: 1,
            start_hour: 12,
            start_minutes: 0,
            end_hour: 13,
            end_minutes: 0,
          },
        ],
      },
    });

    expect(config.business_hours.breaks).toEqual([
      {
        day_of_week: 1,
        start_hour: 12,
        start_minutes: 0,
        end_hour: 13,
        end_minutes: 0,
      },
    ]);
  });
});
