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
      data: { queued: true },
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
    expect(dispatchMock).toHaveBeenCalledWith('setCurrentChatAssignee', {
      conversationId: 17,
      assignee: null,
    });
    expect(dispatchMock).toHaveBeenCalledWith('setCurrentChatTeam', {
      conversationId: 17,
      team: teams[1],
    });
  });
});
