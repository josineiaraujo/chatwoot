import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import QueueReturnDialog from '../components/QueueReturnDialog.vue';
import conversationDistributionAPI from '../api';

const alertMock = vi.fn();
const dispatchMock = vi.fn();
const teams = [
  { id: 1, name: 'Comercial' },
  { id: 2, name: 'Suporte' },
];
const conversation = {
  id: 17,
  status: 'open',
  meta: {
    assignee: { id: 7, name: 'Agente' },
    team: teams[0],
  },
};
const store = {
  getters: {
    getConversationById: vi.fn(() => conversation),
    'teams/getTeams': teams,
  },
  dispatch: dispatchMock,
  commit: vi.fn(),
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => `${key}:${params.teamName || ''}`,
  }),
}));

vi.mock('vuex', () => ({
  useStore: () => store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    returnConversationToQueue: vi.fn(),
  },
}));

const mountComponent = () =>
  shallowMount(QueueReturnDialog, {
    props: {
      chatId: 17,
    },
    global: {
      stubs: {
        Dialog: {
          props: ['disableConfirmButton'],
          emits: ['confirm'],
          methods: {
            open() {},
            close() {},
          },
          template:
            '<div><slot /><button class="confirm-button" type="button" :disabled="disableConfirmButton" @click="$emit(\'confirm\')">confirm</button></div>',
        },
        IbsoftSelect: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select class="team-select" :value="modelValue" @change="$emit(\'update:modelValue\', Number($event.target.value))"><slot /></select>',
        },
      },
    },
  });

describe('QueueReturnDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    store.getters.getConversationById.mockReturnValue(conversation);
    conversationDistributionAPI.returnConversationToQueue.mockResolvedValue({
      data: {
        queued: true,
        status: 'open',
        snoozed_until: null,
        team: teams[1],
      },
    });
    dispatchMock.mockResolvedValue();
  });

  it('returns the conversation to the selected team and updates the store', async () => {
    const wrapper = mountComponent();

    wrapper.vm.open();
    await wrapper.find('.team-select').setValue('2');
    await wrapper.find('.confirm-button').trigger('click');
    await flushPromises();

    expect(
      conversationDistributionAPI.returnConversationToQueue
    ).toHaveBeenCalledWith(17, 2);
    expect(store.commit).toHaveBeenCalledWith('ASSIGN_AGENT', {
      conversationId: 17,
      assignee: null,
    });
    expect(store.commit).toHaveBeenCalledWith('ASSIGN_TEAM', {
      conversationId: 17,
      team: teams[1],
    });
    expect(store.commit).toHaveBeenCalledWith('CHANGE_CONVERSATION_STATUS', {
      conversationId: 17,
      status: 'open',
      snoozedUntil: null,
    });
  });

  it('disables confirmation for a conversation already in the selected queue', async () => {
    store.getters.getConversationById.mockReturnValue({
      ...conversation,
      status: 'open',
      meta: { ...conversation.meta, assignee: null },
    });
    const wrapper = mountComponent();

    wrapper.vm.open();

    expect(
      wrapper.find('.confirm-button').attributes('disabled')
    ).toBeDefined();

    await wrapper.find('.team-select').setValue('2');

    expect(
      wrapper.find('.confirm-button').attributes('disabled')
    ).toBeUndefined();
  });

  it('keeps the original conversation and team while the request is running', async () => {
    let resolveRequest;
    conversationDistributionAPI.returnConversationToQueue.mockReturnValue(
      new Promise(resolve => {
        resolveRequest = resolve;
      })
    );
    const wrapper = mountComponent();

    wrapper.vm.open();
    await wrapper.find('.team-select').setValue('2');
    await wrapper.find('.confirm-button').trigger('click');
    await wrapper.find('.team-select').setValue('1');
    await wrapper.setProps({ chatId: 99 });
    await wrapper.find('.confirm-button').trigger('click');

    expect(
      conversationDistributionAPI.returnConversationToQueue
    ).toHaveBeenCalledTimes(1);
    expect(
      conversationDistributionAPI.returnConversationToQueue
    ).toHaveBeenCalledWith(17, 2);

    resolveRequest({
      data: {
        queued: true,
        status: 'open',
        snoozed_until: null,
        team: teams[1],
      },
    });
    await flushPromises();

    expect(store.commit).toHaveBeenCalledWith('ASSIGN_TEAM', {
      conversationId: 17,
      team: teams[1],
    });
    expect(alertMock).toHaveBeenCalledWith(expect.stringContaining('Suporte'));
  });
});
