export const defaultChathubSettingsConfig = {
  agent_entry_assignment: {
    enabled: true,
    required_percentage: 20,
    minimum_required: 1,
    block_close_when_required: true,
  },
  login_stabilization: {
    enabled: false,
    offline_threshold_minutes: 60,
    window_minutes: 10,
    max_assignments_during_window: 1,
    minimum_online_agents_to_disable: 2,
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

export const normalizeChathubSettingsConfig = config =>
  mergeConfig(defaultChathubSettingsConfig, config || {});
