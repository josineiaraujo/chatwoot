export const defaultPolicyConfig = {
  eligible_sources: [
    'bot_handoff',
    'manual_team_transfer',
    'system_team_transfer',
  ],
  distribution: {
    strategy: 'round_robin',
    min_assignments_on_login: 1,
    max_assignments_per_round: 5,
    assign_all_when_single_agent: false,
    capacity_limit: null,
  },
  redistribution: {
    enabled: false,
    first_response_timeout_minutes: 15,
  },
  unavailable: {
    action: 'wait',
    message: null,
    fallback_team_id: null,
  },
  business_hours: {
    mode: 'inherit_channel',
    timezone: null,
    schedule: [],
  },
  supervisor_alert: {
    enabled: false,
    threshold_minutes: 30,
  },
};

const isObject = value =>
  value && typeof value === 'object' && !Array.isArray(value);

export const cloneConfig = value => JSON.parse(JSON.stringify(value));

export const mergeConfig = (base, overrides = {}) => {
  const output = cloneConfig(base);

  Object.entries(overrides || {}).forEach(([key, value]) => {
    if (isObject(value) && isObject(output[key])) {
      output[key] = mergeConfig(output[key], value);
    } else {
      output[key] = value;
    }
  });

  return output;
};

export const normalizePolicyConfig = config =>
  mergeConfig(defaultPolicyConfig, config || {});
