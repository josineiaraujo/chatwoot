import { shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import SupervisorDashboard from '../views/SupervisorDashboard.vue';

const routerPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
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

vi.mock('../api', () => ({
  default: {
    getSupervisorAlerts: vi.fn(() =>
      Promise.resolve({
        data: {
          summary: { scanned: 0, alerts: 0, by_reason: {}, by_severity: {} },
          alerts: [],
        },
      })
    ),
  },
}));

const mountComponent = () =>
  shallowMount(SupervisorDashboard, {
    global: {
      stubs: {
        Button: {
          props: ['label', 'icon'],
          template:
            '<button :data-icon="icon" @click="$emit(\'click\')">{{ label }}</button>',
        },
        BaseTable: true,
        BaseTableCell: true,
        BaseTableRow: true,
        IbsoftSelect: true,
        Spinner: true,
      },
    },
  });

describe('SupervisorDashboard', () => {
  beforeEach(() => {
    routerPush.mockClear();
  });

  it('does not render the legacy supervisor management action', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).not.toContain(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.MANAGE_SUPERVISORS'
    );
  });

  it('keeps the audit navigation action available', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.EVENT_LOGS'
    );
  });

  it('navigates back to the Chathub home dashboard', async () => {
    const wrapper = mountComponent();
    const homeButton = wrapper
      .findAll('button')
      .find(button =>
        button
          .text()
          .includes(
            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.BACK_TO_HOME'
          )
      );

    await homeButton.trigger('click');

    expect(routerPush).toHaveBeenCalledWith({
      name: 'ibsoft_chathub_home',
      params: { accountId: '1' },
    });
  });
});
