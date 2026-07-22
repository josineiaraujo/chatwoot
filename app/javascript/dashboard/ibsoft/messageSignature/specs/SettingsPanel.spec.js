import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import SettingsPanel from '../components/SettingsPanel.vue';
import messageSignatureAPI from '../api';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  store: {
    dispatch: vi.fn(),
    getters: {},
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (message, [valueKey, value]) => message.replace(`{${valueKey}}`, value),
        key
      ),
  }),
}));

vi.mock('vuex', async importOriginal => ({
  ...(await importOriginal()),
  useStore: () => mocks.store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => mocks.alert(message),
}));

vi.mock('../api', () => ({
  default: {
    getSetting: vi.fn(),
    updateSetting: vi.fn(),
  },
}));

const inboxes = [
  { id: 2, name: 'WhatsApp', channel_type: 'Channel::Whatsapp' },
  { id: 1, name: 'Site', channel_type: 'Channel::WebWidget' },
];

const mountComponent = () =>
  shallowMount(SettingsPanel, {
    global: {
      stubs: {
        BaseSettingsHeader: true,
        Spinner: true,
        ChannelIcon: true,
        ChannelName: true,
        Checkbox: {
          props: ['modelValue'],
          template: '<input type="checkbox" :checked="modelValue" />',
        },
        ToggleSwitch: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button class="toggle" @click="$emit(\'update:modelValue\', !modelValue)">{{ modelValue }}</button>',
        },
        Button: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template:
            '<button class="save" :disabled="isLoading" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

describe('MessageSignatureSettingsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.store.getters = {
      'inboxes/getInboxes': inboxes,
      getCurrentUser: { id: 7, name: 'Maria Suporte' },
    };
    mocks.store.dispatch.mockResolvedValue();
    messageSignatureAPI.getSetting.mockResolvedValue({
      data: { enabled: true, inbox_ids: [2] },
    });
    messageSignatureAPI.updateSetting.mockResolvedValue({
      data: { enabled: true, inbox_ids: [1, 2] },
    });
  });

  it('loads the account configuration and available channels', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(messageSignatureAPI.getSetting).toHaveBeenCalledOnce();
    expect(mocks.store.dispatch).toHaveBeenCalledWith('inboxes/get');
    expect(wrapper.text()).toContain('Maria Suporte');
    expect(wrapper.vm.enabled).toBe(true);
    expect(wrapper.vm.selectedInboxIds).toEqual([2]);
  });

  it('adds a channel and persists only the normalized configuration', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.toggleInbox(1);
    await wrapper.vm.saveSetting();

    expect(messageSignatureAPI.updateSetting).toHaveBeenCalledWith({
      enabled: true,
      inbox_ids: [1, 2],
    });
    expect(mocks.alert).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.SAVED'
    );
  });

  it('does not enable signatures without a selected channel', async () => {
    messageSignatureAPI.getSetting.mockResolvedValue({
      data: { enabled: false, inbox_ids: [] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.enabled = true;
    await wrapper.vm.saveSetting();

    expect(messageSignatureAPI.updateSetting).not.toHaveBeenCalled();
    expect(mocks.alert).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ERRORS.CHANNEL_REQUIRED'
    );
  });

  it('reports loading failures without leaving the screen busy', async () => {
    messageSignatureAPI.getSetting.mockRejectedValue(new Error('failed'));
    const wrapper = mountComponent();
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ERRORS.LOAD'
    );
    expect(wrapper.vm.isFetching).toBe(false);
  });
});
