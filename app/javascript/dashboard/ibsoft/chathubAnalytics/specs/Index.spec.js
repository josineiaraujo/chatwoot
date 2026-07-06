import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import ChathubAnalyticsIndex from '../views/Index.vue';
import analyticsAPI from '../api';

const routerPush = vi.fn();
const storeDispatch = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'pt_BR' },
    t: (key, params = {}) =>
      Object.keys(params).reduce(
        (label, param) => label.replace(`{${param}}`, params[param]),
        key
      ),
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: routerPush }),
}));

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: storeDispatch,
    getters: {
      getCurrentUser: {
        accounts: [
          {
            id: 1,
            role: 'administrator',
            permissions: ['ibsoft_conversation_distribution_supervise'],
          },
        ],
      },
      'inboxes/getInboxes': [],
      'teams/getTeams': [],
    },
  }),
}));

vi.mock('../api', () => ({
  default: {
    getAgentDashboard: vi.fn(() =>
      Promise.resolve({
        data: {
          summary: {
            open_assigned: 1,
            average_reply_seconds: 0,
            redistributions_away_count: 0,
            redistribution_basis_count: 0,
            resolved_count: 0,
          },
          by_team: [],
          daily_response: [],
          suggestions: [],
        },
      })
    ),
    getSupervisorDashboard: vi.fn(() =>
      Promise.resolve({
        data: {
          summary: {
            open_conversations: 1,
            unassigned_conversations: 0,
            average_first_response_seconds: 0,
            redistributions_count: 0,
            redistribution_basis_count: 0,
          },
          top_agents: [],
          redistribution_ranking: [],
          slow_response_ranking: [],
          by_team: [],
          daily_volume: [],
          hourly_heatmap: [],
          suggestions: [],
        },
      })
    ),
  },
}));

const mountComponent = () =>
  shallowMount(ChathubAnalyticsIndex, {
    global: {
      stubs: {
        Button: {
          props: ['label', 'icon', 'faded'],
          template:
            '<button :data-icon="icon" :data-faded="faded" @click="$emit(\'click\')">{{ label }}</button>',
        },
        IbsoftSelect: true,
        Spinner: true,
        MetricCard: true,
        BarList: true,
        TrendBars: true,
        SuggestionList: true,
      },
    },
  });

describe('ChathubAnalyticsIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('allows supervisors to switch from team dashboard to their individual dashboard', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(analyticsAPI.getSupervisorDashboard).toHaveBeenCalledTimes(1);
    expect(analyticsAPI.getAgentDashboard).not.toHaveBeenCalled();

    const agentDashboardButton = wrapper
      .findAll('button')
      .find(button =>
        button.text().includes('IBSOFT_THEME.CHATHUB_ANALYTICS.TABS.AGENT')
      );

    await agentDashboardButton.trigger('click');
    await flushPromises();

    expect(analyticsAPI.getAgentDashboard).toHaveBeenCalledTimes(1);
  });
});
