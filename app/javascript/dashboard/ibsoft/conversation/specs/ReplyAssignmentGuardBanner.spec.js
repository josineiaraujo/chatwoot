import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import ReplyAssignmentGuardBanner from '../components/ReplyAssignmentGuardBanner.vue';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  store: {
    dispatch: vi.fn(),
    getters: {},
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vuex', () => ({
  useStore: () => mocks.store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => mocks.alert(message),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => ({
    get value() {
      return mocks.store.getters[key];
    },
  }),
}));

const currentUser = { id: 7, name: 'Agente' };
let currentChat;

const mountComponent = (props = {}) =>
  shallowMount(ReplyAssignmentGuardBanner, {
    props,
    global: {
      stubs: {
        Button: {
          props: ['label', 'isLoading'],
          emits: ['click'],
          template:
            '<button type="button" :disabled="isLoading" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

describe('ReplyAssignmentGuardBanner', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    currentChat = {
      id: 42,
      status: 'pending',
      meta: { assignee: null },
    };
    mocks.store.getters = {
      getSelectedChat: currentChat,
      getCurrentUser: currentUser,
      getConversationById: vi.fn(() => currentChat),
    };
    mocks.store.dispatch.mockImplementation(async (action, payload) => {
      if (action === 'assignAgent') {
        currentChat.meta.assignee = { id: payload.agentId };
      }
      if (action === 'toggleStatus') {
        currentChat.status = payload.status;
      }
    });
  });

  it('offers the handoff before the agent starts typing', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CONVERSATION_REPLY_GUARD.HANDOFF_MESSAGE'
    );
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CONVERSATION_REPLY_GUARD.ACTION'
    );
  });

  it('uses the direct assignment message for an open conversation', () => {
    currentChat.status = 'open';
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CONVERSATION_REPLY_GUARD.ASSIGN_MESSAGE'
    );
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CONVERSATION_REPLY_GUARD.ACTION'
    );
  });

  it('assigns before opening an unassigned automation conversation', async () => {
    const wrapper = mountComponent();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(mocks.store.dispatch).toHaveBeenNthCalledWith(1, 'assignAgent', {
      conversationId: 42,
      agentId: 7,
    });
    expect(mocks.store.dispatch).toHaveBeenNthCalledWith(2, 'toggleStatus', {
      conversationId: 42,
      status: 'open',
    });
    expect(mocks.alert).toHaveBeenCalledWith(
      'CONVERSATION.BOT_HANDOFF_SUCCESS'
    );
  });

  it('only opens a pending conversation already owned by the current agent', async () => {
    currentChat.meta.assignee = currentUser;
    const wrapper = mountComponent();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(mocks.store.dispatch).toHaveBeenCalledTimes(1);
    expect(mocks.store.dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 42,
      status: 'open',
    });
  });

  it('only assigns an open conversation that has no owner', async () => {
    currentChat.status = 'open';
    const wrapper = mountComponent();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(mocks.store.dispatch).toHaveBeenCalledTimes(1);
    expect(mocks.store.dispatch).toHaveBeenCalledWith('assignAgent', {
      conversationId: 42,
      agentId: 7,
    });
    expect(mocks.alert).toHaveBeenCalledWith('CONVERSATION.CHANGE_AGENT');
  });

  it('keeps the guard active when the store does not confirm the assignment', async () => {
    mocks.store.dispatch.mockResolvedValue();
    const wrapper = mountComponent();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(mocks.store.dispatch).toHaveBeenCalledTimes(1);
    expect(mocks.alert).toHaveBeenCalledWith('CONVERSATION.BOT_HANDOFF_ERROR');
    expect(wrapper.find('button').attributes('disabled')).toBeUndefined();
  });

  it('does not display while the agent writes a private note', () => {
    const wrapper = mountComponent({ isOnPrivateNote: true });

    expect(wrapper.isVisible()).toBe(false);
  });
});
