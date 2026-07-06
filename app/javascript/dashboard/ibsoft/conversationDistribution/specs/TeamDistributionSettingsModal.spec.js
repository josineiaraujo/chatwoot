import { flushPromises, shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi, beforeEach } from 'vitest';

import TeamDistributionSettingsModal from '../components/TeamDistributionSettingsModal.vue';
import conversationDistributionAPI from '../api';

const alertMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    getTeamPolicy: vi.fn(),
    getPolicies: vi.fn(),
    updateTeamPolicy: vi.fn(),
  },
}));

const mountComponent = () =>
  shallowMount(TeamDistributionSettingsModal, {
    props: {
      show: true,
      team: { id: 270, name: 'Suporte' },
    },
    global: {
      stubs: {
        'woot-modal': {
          template: '<div><slot /></div>',
        },
        'woot-modal-header': true,
        Button: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template:
            '<button type="button" :disabled="isLoading" @click="$emit(\'click\')">{{ label }}</button>',
        },
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

describe('TeamDistributionSettingsModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    conversationDistributionAPI.getTeamPolicy.mockResolvedValue({
      data: {
        override_channel_policy: true,
        distribution_policy_id: 15,
        native_assignment: {},
      },
    });
    conversationDistributionAPI.getPolicies.mockResolvedValue({
      data: {
        policies: [{ id: 15, name: 'Comercial' }],
      },
    });
  });

  it('closes the modal after saving the team distribution settings', async () => {
    conversationDistributionAPI.updateTeamPolicy.mockResolvedValue({
      data: {
        override_channel_policy: true,
        distribution_policy_id: 15,
        native_assignment: {},
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.findAll('button').at(-1).trigger('click');
    await flushPromises();

    expect(conversationDistributionAPI.updateTeamPolicy).toHaveBeenCalledWith(
      270,
      {
        override_channel_policy: true,
        distribution_policy_id: 15,
      }
    );
    expect(wrapper.emitted('update:show')).toEqual([[false]]);
  });

  it('keeps the modal open when saving fails', async () => {
    conversationDistributionAPI.updateTeamPolicy.mockRejectedValue(
      new Error('request failed')
    );

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.findAll('button').at(-1).trigger('click');
    await flushPromises();

    expect(wrapper.emitted('update:show')).toBeUndefined();
  });
});
