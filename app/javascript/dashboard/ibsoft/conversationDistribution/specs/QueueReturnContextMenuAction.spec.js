import { shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import fluentIcons from 'shared/components/FluentIcon/icons.json';
import QueueReturnContextMenuAction from '../components/QueueReturnContextMenuAction.vue';

const conversation = {
  id: 17,
  status: 'open',
  meta: {
    assignee: { id: 7, name: 'Agente' },
    team: { id: 1, name: 'Comercial' },
  },
};
const store = {
  getters: {
    getConversationById: vi.fn(() => conversation),
    getCurrentUser: { id: 7 },
  },
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => `${key}:${params.teamName || ''}`,
  }),
}));

vi.mock('vuex', () => ({
  useStore: () => store,
}));

const mountComponent = () =>
  shallowMount(QueueReturnContextMenuAction, {
    props: {
      chatId: 17,
    },
    global: {
      stubs: {
        MenuItem: {
          props: ['option'],
          emits: ['click'],
          template:
            '<button class="queue-return-menu-item" type="button" :data-icon="option.icon" @click="$emit(\'click\', $event)">{{ option.label }}</button>',
        },
      },
    },
  });

describe('QueueReturnContextMenuAction', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    store.getters.getConversationById.mockReturnValue(conversation);
    store.getters.getCurrentUser = { id: 7 };
  });

  it('is visible only for the current assignee of an open conversation', () => {
    const menuItem = mountComponent().find('.queue-return-menu-item');

    expect(menuItem.exists()).toBe(true);
    expect(
      fluentIcons[`${menuItem.attributes('data-icon')}-outline`]
    ).toBeTruthy();

    store.getters.getCurrentUser = { id: 99 };

    expect(mountComponent().find('.queue-return-menu-item').exists()).toBe(
      false
    );
  });

  it('emits an open request without owning the dialog lifecycle', async () => {
    const wrapper = mountComponent();

    await wrapper.find('.queue-return-menu-item').trigger('click');

    expect(wrapper.emitted('open')).toEqual([[]]);
  });
});
