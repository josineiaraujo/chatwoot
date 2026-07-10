import { flushPromises, shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import ErpSettings from '../views/Index.vue';
import erpAPI from '../api';

const alertMock = vi.fn();
const closeDialogMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.keys(values).reduce(
        (message, valueKey) =>
          message.replace(`{${valueKey}}`, values[valueKey]),
        key
      ),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    getConnections: vi.fn(),
    createConnection: vi.fn(),
    updateConnection: vi.fn(),
    testConnection: vi.fn(),
    deleteConnection: vi.fn(),
  },
}));

const providers = [
  { key: 'ixc', label: 'IXC Provedor', auth_types: ['basic'] },
  { key: 'sgp', label: 'SGP', auth_types: ['basic', 'token_app'] },
];

const connections = [
  {
    id: 10,
    name: 'IXC produção',
    provider: 'ixc',
    provider_label: 'IXC Provedor',
    auth_type: 'basic',
    base_url: 'https://ixc.example.com.br',
    active: false,
    credentials_configured: true,
  },
];

const mountComponent = () =>
  shallowMount(ErpSettings, {
    global: {
      stubs: {
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Dialog: {
          props: ['disableConfirmButton'],
          emits: ['confirm', 'close'],
          setup(props, { slots, emit, expose }) {
            expose({ open: vi.fn(), close: closeDialogMock });
            return () =>
              h('div', { class: 'dialog-stub' }, [
                slots.default?.(),
                h(
                  'button',
                  {
                    class: 'dialog-confirm',
                    disabled: props.disableConfirmButton,
                    onClick: () => emit('confirm'),
                  },
                  'confirm'
                ),
              ]);
          },
        },
        Spinner: true,
        ToggleSwitch: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button type="button" @click="$emit(\'update:modelValue\', !modelValue)">{{ modelValue }}</button>',
        },
        IbsoftSelect: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><slot /></select>',
        },
      },
    },
  });

describe('ErpSettings', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    closeDialogMock.mockClear();
    erpAPI.getConnections.mockResolvedValue({
      data: { providers, connections },
    });
    erpAPI.createConnection.mockResolvedValue({ data: {} });
    erpAPI.updateConnection.mockResolvedValue({ data: {} });
    erpAPI.testConnection.mockResolvedValue({
      data: {
        connection: {
          ...connections[0],
          last_test_status: 'success',
        },
        test: { success: true, status: 'success' },
      },
    });
    erpAPI.deleteConnection.mockResolvedValue({ data: {} });
  });

  it('loads configured ERP connections on mount', async () => {
    const wrapper = mountComponent();

    await flushPromises();

    expect(erpAPI.getConnections).toHaveBeenCalled();
    expect(wrapper.text()).toContain('IXC produção');
    expect(wrapper.text()).toContain('IXC Provedor');
  });

  it('creates a new SGP token/app connection', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.openCreate();
    wrapper.vm.form.name = 'SGP produção';
    wrapper.vm.form.provider = 'sgp';
    wrapper.vm.form.auth_type = 'token_app';
    wrapper.vm.form.base_url = 'https://sgp.example.com.br';
    wrapper.vm.form.credentials = { token: 'token', app: 'app' };

    await wrapper.vm.saveConnection();

    expect(erpAPI.createConnection).toHaveBeenCalledWith({
      name: 'SGP produção',
      provider: 'sgp',
      auth_type: 'token_app',
      base_url: 'https://sgp.example.com.br',
      active: false,
      credentials: { token: 'token', app: 'app' },
      settings: {},
    });
    expect(closeDialogMock).toHaveBeenCalled();
  });

  it('marks an existing connection as the default ERP', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.activateConnection(connections[0]);

    expect(erpAPI.updateConnection).toHaveBeenCalledWith(10, { active: true });
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVATED'
    );
  });

  it('tests an ERP connection without changing ERP data', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.testConnection(connections[0]);

    expect(erpAPI.testConnection).toHaveBeenCalledWith(10);
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.STATUS.SUCCESS'
    );
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.SUCCESS'
    );
  });
});
