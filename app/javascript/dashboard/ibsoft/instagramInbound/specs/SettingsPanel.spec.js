import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import SettingsPanel from '../components/SettingsPanel.vue';
import instagramInboundAPI from '../api';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => mocks.alert(message),
}));

vi.mock('../api', () => ({
  default: {
    getInboxPolicy: vi.fn(),
    updateInboxPolicy: vi.fn(),
  },
}));

const policy = {
  inbox_id: 4,
  create_from_story_interactions: false,
  create_from_shared_reels_and_stories: true,
  create_from_shared_posts: false,
};

const mountComponent = (inboxId = 4) =>
  shallowMount(SettingsPanel, {
    props: { inboxId },
    global: {
      stubs: {
        Spinner: true,
        ToggleSwitch: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button class="toggle" @click="$emit(\'update:modelValue\', !modelValue)">{{ modelValue }}</button>',
        },
        Button: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template: `<button :class="label.includes('SAVE') ? 'save' : 'retry'" :disabled="isLoading" @click="$emit('click')">{{ label }}</button>`,
        },
      },
    },
  });

describe('InstagramInboundSettingsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    instagramInboundAPI.getInboxPolicy.mockResolvedValue({ data: policy });
    instagramInboundAPI.updateInboxPolicy.mockResolvedValue({ data: policy });
  });

  it('loads and displays the policy for the selected Instagram inbox', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(instagramInboundAPI.getInboxPolicy).toHaveBeenCalledWith(4);
    expect(wrapper.findAll('.toggle').map(toggle => toggle.text())).toEqual([
      'false',
      'true',
      'false',
    ]);
    expect(wrapper.text()).toContain(
      'IBSOFT_INSTAGRAM_INBOUND.ACTIVE_CONVERSATION_NOTICE'
    );
  });

  it('updates a setting and saves the complete policy', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.findAll('.toggle')[0].trigger('click');
    await wrapper.find('.save').trigger('click');
    await flushPromises();

    expect(instagramInboundAPI.updateInboxPolicy).toHaveBeenCalledWith(4, {
      create_from_story_interactions: true,
      create_from_shared_reels_and_stories: true,
      create_from_shared_posts: false,
    });
    expect(mocks.alert).toHaveBeenCalledWith('IBSOFT_INSTAGRAM_INBOUND.SAVED');
  });

  it('shows a recoverable error state when loading fails', async () => {
    instagramInboundAPI.getInboxPolicy
      .mockRejectedValueOnce(new Error('failure'))
      .mockResolvedValueOnce({ data: policy });
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.find('.retry').exists()).toBe(true);
    await wrapper.find('.retry').trigger('click');
    await flushPromises();

    expect(instagramInboundAPI.getInboxPolicy).toHaveBeenCalledTimes(2);
    expect(wrapper.find('.retry').exists()).toBe(false);
  });

  it('reloads the policy when the channel changes', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.setProps({ inboxId: 8 });
    await flushPromises();

    expect(instagramInboundAPI.getInboxPolicy).toHaveBeenLastCalledWith(8);
  });
});
