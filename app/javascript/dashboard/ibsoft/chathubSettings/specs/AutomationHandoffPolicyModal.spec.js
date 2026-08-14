import { flushPromises, shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import AutomationHandoffPolicyModal from '../components/AutomationHandoffPolicyModal.vue';
import conversationDistributionAPI from 'dashboard/ibsoft/conversationDistribution/api';

const alertMock = vi.fn();
const closeDialogMock = vi.fn();
const dispatchMock = vi.hoisted(() => vi.fn());

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: dispatchMock,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('dashboard/ibsoft/conversationDistribution/api', () => ({
  default: {
    getInboxPolicy: vi.fn(),
    updateInboxPolicy: vi.fn(),
    getPolicies: vi.fn(),
    getAutomationHandoffPolicy: vi.fn(),
    updateAutomationHandoffPolicy: vi.fn(),
  },
}));

const mountComponent = () =>
  shallowMount(AutomationHandoffPolicyModal, {
    props: {
      teams: [{ id: 270, name: 'Suporte' }],
    },
    global: {
      stubs: {
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
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
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

describe('AutomationHandoffPolicyModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    dispatchMock.mockResolvedValue({});
    closeDialogMock.mockClear();
    conversationDistributionAPI.getInboxPolicy.mockResolvedValue({
      data: {
        distribution_policy_id: 15,
        native_assignment: {},
      },
    });
    conversationDistributionAPI.getPolicies.mockResolvedValue({
      data: {
        policies: [{ id: 15, name: 'Comercial' }],
      },
    });
    conversationDistributionAPI.getAutomationHandoffPolicy.mockResolvedValue({
      data: {
        enabled: true,
        stale_after_minutes: 10,
        timeout_action: 'forward_to_team',
        target_team_id: 270,
        customer_message_enabled: true,
        customer_message: 'Vamos encaminhar seu atendimento.',
        close_warning_enabled: false,
        close_warning_message: '',
        close_warning_delay_minutes: 1,
        close_final_message_enabled: false,
        close_final_message: '',
      },
    });
    conversationDistributionAPI.updateInboxPolicy.mockResolvedValue({
      data: {
        distribution_policy_id: 15,
        native_assignment: {},
      },
    });
    conversationDistributionAPI.updateAutomationHandoffPolicy.mockResolvedValue(
      {
        data: {
          enabled: true,
          stale_after_minutes: 10,
          timeout_action: 'forward_to_team',
          target_team_id: 270,
          customer_message_enabled: true,
          customer_message: 'Vamos encaminhar seu atendimento.',
          close_warning_enabled: false,
          close_warning_message: '',
          close_warning_delay_minutes: 1,
          close_final_message_enabled: false,
          close_final_message: '',
        },
      }
    );
  });

  it('loads distribution and automation settings when opened for a channel', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({ id: 1, name: 'Site' });
    await flushPromises();

    expect(conversationDistributionAPI.getInboxPolicy).toHaveBeenCalledWith(1);
    expect(conversationDistributionAPI.getPolicies).toHaveBeenCalled();
    expect(
      conversationDistributionAPI.getAutomationHandoffPolicy
    ).toHaveBeenCalledWith(1);
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.DISTRIBUTION_TITLE'
    );
  });

  it('disables native Chatwoot auto-assignment when the channel has it enabled', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({
      id: 1,
      name: 'Site',
      enable_auto_assignment: true,
    });
    await flushPromises();

    expect(dispatchMock).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 1,
      formData: false,
      enable_auto_assignment: false,
    });
    expect(wrapper.find('[role="status"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain(
      'IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT'
    );
  });

  it('disables native Chatwoot auto-assignment when the policy endpoint reports it enabled', async () => {
    conversationDistributionAPI.getInboxPolicy.mockResolvedValueOnce({
      data: {
        distribution_policy_id: null,
        native_assignment: {
          inbox_auto_assignment_enabled: true,
        },
      },
    });
    const wrapper = mountComponent();

    await wrapper.vm.open({ id: 1, name: 'Site' });
    await flushPromises();

    expect(dispatchMock).toHaveBeenCalledWith('inboxes/updateInbox', {
      id: 1,
      formData: false,
      enable_auto_assignment: false,
    });
  });

  it('saves distribution and automation settings together', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({ id: 1, name: 'Site' });
    await flushPromises();

    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();

    expect(conversationDistributionAPI.updateInboxPolicy).toHaveBeenCalledWith(
      1,
      {
        distribution_policy_id: 15,
      }
    );
    expect(
      conversationDistributionAPI.updateAutomationHandoffPolicy
    ).toHaveBeenCalledWith(1, {
      enabled: true,
      stale_after_minutes: 10,
      timeout_action: 'forward_to_team',
      target_team_id: 270,
      customer_message_enabled: true,
      customer_message: 'Vamos encaminhar seu atendimento.',
      close_warning_enabled: false,
      close_warning_message: '',
      close_warning_delay_minutes: 1,
      close_final_message_enabled: false,
      close_final_message: '',
    });
    expect(closeDialogMock).toHaveBeenCalled();
  });

  it('saves a close action without a target team', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({ id: 1, name: 'Site' });
    await flushPromises();
    const automationTab = wrapper
      .findAll('button')
      .find(button =>
        button
          .text()
          .includes(
            'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TABS.AUTOMATION'
          )
      );

    await automationTab.trigger('click');
    await wrapper
      .find('[data-testid="automation-action-close_conversation"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="automation-stale-after"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="automation-target-team"]').exists()
    ).toBe(false);

    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();

    expect(
      conversationDistributionAPI.updateAutomationHandoffPolicy
    ).toHaveBeenCalledWith(1, {
      enabled: true,
      stale_after_minutes: 10,
      timeout_action: 'close_conversation',
      target_team_id: null,
      customer_message_enabled: true,
      customer_message: 'Vamos encaminhar seu atendimento.',
      close_warning_enabled: false,
      close_warning_message: '',
      close_warning_delay_minutes: 1,
      close_final_message_enabled: false,
      close_final_message: '',
    });
    expect(closeDialogMock).toHaveBeenCalled();
  });

  it('saves the warning delay and both closure messages', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({ id: 1, name: 'Site' });
    await flushPromises();
    const automationTab = wrapper
      .findAll('button')
      .find(button =>
        button
          .text()
          .includes(
            'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TABS.AUTOMATION'
          )
      );

    await automationTab.trigger('click');
    await wrapper
      .find('[data-testid="automation-action-close_conversation"]')
      .trigger('click');

    const warningSection = wrapper.find(
      '[data-testid="automation-close-warning"]'
    );
    await warningSection.find('button').trigger('click');
    await warningSection
      .find('[data-testid="automation-close-warning-delay"]')
      .setValue('5');
    await warningSection
      .find('textarea')
      .setValue('Você ainda está aí? O atendimento será encerrado.');

    const finalMessageSection = wrapper.find(
      '[data-testid="automation-close-final-message"]'
    );
    await finalMessageSection.find('button').trigger('click');
    await finalMessageSection
      .find('textarea')
      .setValue('Atendimento encerrado por falta de resposta.');

    await wrapper.find('.dialog-confirm').trigger('click');
    await flushPromises();

    expect(
      conversationDistributionAPI.updateAutomationHandoffPolicy
    ).toHaveBeenCalledWith(1, {
      enabled: true,
      stale_after_minutes: 10,
      timeout_action: 'close_conversation',
      target_team_id: null,
      customer_message_enabled: true,
      customer_message: 'Vamos encaminhar seu atendimento.',
      close_warning_enabled: true,
      close_warning_message:
        'Você ainda está aí? O atendimento será encerrado.',
      close_warning_delay_minutes: 5,
      close_final_message_enabled: true,
      close_final_message: 'Atendimento encerrado por falta de resposta.',
    });
    expect(closeDialogMock).toHaveBeenCalled();
  });
});
