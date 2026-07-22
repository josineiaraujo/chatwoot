import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import TransferToAgentDialog from '../components/TransferToAgentDialog.vue';

const alertMock = vi.fn();
const dispatchMock = vi.fn();
const agents = [{ id: 7, name: 'Camila', availability_status: 'online' }];
const store = {
  getters: {
    getCurrentUser: { id: 3 },
    getCurrentAccountId: 1,
    'inboxAssignableAgents/getAssignableAgents': vi.fn(() => agents),
  },
  dispatch: dispatchMock,
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => `${key}:${params.agentName || ''}`,
  }),
}));

vi.mock('vuex', () => ({
  useStore: () => store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

const mountComponent = () =>
  shallowMount(TransferToAgentDialog, {
    props: { chatId: 17, inboxId: 4 },
    global: {
      stubs: {
        Dialog: {
          props: ['disableConfirmButton'],
          emits: ['confirm'],
          methods: { open() {}, close() {} },
          template:
            '<div><slot /><button class="confirm-button" type="button" :disabled="disableConfirmButton" @click="$emit(\'confirm\')">confirm</button></div>',
        },
        MultiselectDropdown: {
          props: ['options', 'selectedItem'],
          emits: ['select'],
          template:
            '<button class="agent-select" type="button" @click="$emit(\'select\', options[0])">select</button>',
        },
      },
    },
  });

describe('TransferToAgentDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    dispatchMock.mockResolvedValue();
  });

  it('loads agents and transfers the conversation to the selected agent', async () => {
    const wrapper = mountComponent();

    wrapper.vm.open();
    await flushPromises();
    await wrapper.find('.agent-select').trigger('click');
    await wrapper.find('.confirm-button').trigger('click');
    await flushPromises();

    expect(dispatchMock).toHaveBeenCalledWith('inboxAssignableAgents/fetch', [
      4,
    ]);
    expect(dispatchMock).toHaveBeenCalledWith('assignAgent', {
      conversationId: 17,
      agentId: 7,
    });
  });

  it('keeps the original conversation and agent while the request is running', async () => {
    let resolveAssignment;
    const assignmentRequest = new Promise(resolve => {
      resolveAssignment = resolve;
    });
    dispatchMock.mockImplementation(action => {
      if (action === 'assignAgent') return assignmentRequest;

      return Promise.resolve();
    });
    const wrapper = mountComponent();

    wrapper.vm.open();
    await flushPromises();
    await wrapper.find('.agent-select').trigger('click');
    await wrapper.find('.confirm-button').trigger('click');
    await wrapper.setProps({ chatId: 99, inboxId: 8 });
    await wrapper.find('.confirm-button').trigger('click');

    expect(
      dispatchMock.mock.calls.filter(([action]) => action === 'assignAgent')
    ).toEqual([
      [
        'assignAgent',
        {
          conversationId: 17,
          agentId: 7,
        },
      ],
    ]);

    resolveAssignment();
    await flushPromises();
    expect(alertMock).toHaveBeenCalledWith(expect.stringContaining('Camila'));
  });

  it('handles a failure while refreshing assignable agents', async () => {
    dispatchMock.mockRejectedValueOnce(new Error('network unavailable'));
    const wrapper = mountComponent();

    wrapper.vm.open();
    await flushPromises();

    expect(alertMock).toHaveBeenCalledWith(
      expect.stringContaining('LOAD_FAILED')
    );
    expect(
      wrapper.find('.confirm-button').attributes('disabled')
    ).toBeDefined();
  });
});
