import { describe, expect, it } from 'vitest';

import { normalizeChathubSettingsConfig } from '../defaults';

describe('#normalizeChathubSettingsConfig', () => {
  it('merges saved attendance settings with defaults', () => {
    const config = normalizeChathubSettingsConfig({
      agent_entry_assignment: {
        required_percentage: 35,
      },
    });

    expect(config.agent_entry_assignment).toMatchObject({
      enabled: true,
      required_percentage: 35,
      minimum_required: 1,
      block_close_when_required: true,
    });
    expect(config.login_stabilization).toMatchObject({
      enabled: false,
      offline_threshold_minutes: 60,
    });
  });
});
