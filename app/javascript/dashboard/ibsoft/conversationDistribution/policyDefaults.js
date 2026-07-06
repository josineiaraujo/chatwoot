export const defaultPolicyConfig = {
  eligible_sources: [
    'bot_handoff',
    'manual_team_transfer',
    'system_team_transfer',
  ],
  distribution: {
    max_assignments_per_round_enabled: true,
    max_assignments_per_round: 5,
    assignment_order: 'round_robin',
    conversation_priority: 'longest_waiting',
    assignment_limit_mode: 'open_conversations',
    open_conversation_limit: 5,
    capacity_ignore_customer_waiting_enabled: false,
    capacity_ignore_customer_waiting_minutes: 1440,
    capacity_excluded_labels: [],
    fair_distribution_limit: 100,
    fair_distribution_window: 3600,
  },
  redistribution: {
    enabled: false,
    first_response_timeout_minutes: 15,
  },
  assignment_confirmation: {
    enabled: false,
    message: null,
    only_before_first_reply: true,
  },
  unavailable: {
    action: 'wait',
    message: null,
    fallback_team_id: null,
  },
  unavailability: {
    no_available_agent: {
      action: 'wait',
      message: null,
      fallback_team_id: null,
    },
    outside_business_hours: {
      action: 'wait',
      message: null,
      fallback_team_id: null,
    },
  },
  business_hours: {
    mode: 'inherit_channel',
    timezone: null,
    schedule: [],
    breaks: [],
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

const isCustomUnavailableConfig = config =>
  Boolean(
    config &&
      (config.action !== 'wait' || config.message || config.fallback_team_id)
  );

const withLegacyUnavailability = (normalizedConfig, sourceConfig = {}) => {
  const output = cloneConfig(normalizedConfig);

  if (sourceConfig.unavailability) {
    output.unavailable = cloneConfig(defaultPolicyConfig.unavailable);
    return output;
  }

  if (isCustomUnavailableConfig(sourceConfig.unavailable)) {
    output.unavailability = {
      no_available_agent: mergeConfig(
        defaultPolicyConfig.unavailable,
        sourceConfig.unavailable
      ),
      outside_business_hours: mergeConfig(
        defaultPolicyConfig.unavailable,
        sourceConfig.unavailable
      ),
    };
  }

  return output;
};

export const normalizePolicyConfig = config =>
  withLegacyUnavailability(
    mergeConfig(defaultPolicyConfig, config || {}),
    config || {}
  );
