import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import BaseHeatmap from 'dashboard/routes/dashboard/settings/reports/components/heatmaps/BaseHeatmap.vue';

const localeMocks = vi.hoisted(() => ({
  formatDate: vi.fn(() => '4 ago 2026'),
}));

vi.mock('shared/ibsoft/locale/dateTime', () => ({
  ibsoftFormatDate: localeMocks.formatDate,
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('@chatwoot/viz', () => ({
  HeatmapChart: {
    name: 'HeatmapChart',
    props: ['data', 'ariaLabel', 'colors', 'formatValue'],
    template: '<div />',
  },
}));

describe('BaseHeatmap private locale integration', () => {
  it('formats row descriptions with the active dashboard locale', () => {
    const wrapper = shallowMount(BaseHeatmap, {
      props: {
        heatmapData: [
          {
            timestamp: Date.parse('2026-08-04T12:00:00Z') / 1000,
            value: 3,
          },
        ],
        ariaLabel: 'Heatmap',
        formatValue: value => String(value),
      },
    });

    expect(localeMocks.formatDate).toHaveBeenCalledWith(
      expect.any(Date),
      'MMM d, yyyy'
    );

    const chart = wrapper.findComponent({ name: 'HeatmapChart' });
    if (chart.exists()) {
      expect(chart.props('data').rows[0].description).toBe('4 ago 2026');
    } else {
      expect(wrapper.text()).toContain('4 ago 2026');
    }
  });
});
