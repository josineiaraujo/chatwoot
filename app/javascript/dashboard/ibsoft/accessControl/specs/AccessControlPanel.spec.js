import { flushPromises, shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import AccessControlPanel from '../components/AccessControlPanel.vue';
import accessControlAPI from '../api';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      Object.keys(params).reduce(
        (label, param) => label.replace(`{${param}}`, params[param]),
        key
      ),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('../api', () => ({
  default: {
    getRoles: vi.fn(),
    createRole: vi.fn(),
    updateRole: vi.fn(),
    deleteRole: vi.fn(),
    getAssignments: vi.fn(),
    saveAssignment: vi.fn(),
    deleteAssignment: vi.fn(),
  },
}));

const mountComponent = () =>
  shallowMount(AccessControlPanel, {
    global: {
      stubs: {
        Button: {
          props: ['label', 'icon'],
          template:
            '<button :data-icon="icon" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Dialog: {
          emits: ['confirm', 'close'],
          setup(_props, { slots, expose }) {
            expose({ open: vi.fn(), close: vi.fn() });
            return () => h('div', { class: 'dialog-stub' }, slots.default?.());
          },
        },
        IbsoftSelect: true,
        Spinner: true,
      },
    },
  });

describe('AccessControlPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    accessControlAPI.getRoles.mockResolvedValue({
      data: {
        roles: [
          {
            id: 1,
            name: 'Supervisor',
            description: 'Supervisão',
            permissions: ['ibsoft_conversation_distribution_supervise'],
            assignments_count: 1,
          },
        ],
        available_permissions: [],
      },
    });
    accessControlAPI.getAssignments.mockResolvedValue({
      data: {
        assignments: [
          {
            id: 10,
            role: { id: 1, name: 'Supervisor' },
            user: { id: 20, name: 'Agente', email: 'agente@example.com' },
          },
        ],
        users: [{ id: 20, name: 'Agente', email: 'agente@example.com' }],
        available_users: [],
      },
    });
  });

  it('keeps agent linking out of the main profile list', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain('Supervisor');
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.VIEW_AGENTS'
    );
    expect(wrapper.text()).not.toContain(
      'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.ASSIGNMENTS_TITLE'
    );
  });
});
