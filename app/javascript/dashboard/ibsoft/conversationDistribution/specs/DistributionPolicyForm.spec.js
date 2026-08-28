import { shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import DistributionPolicyForm from '../components/DistributionPolicyForm.vue';

const mocks = vi.hoisted(() => ({
  store: {
    dispatch: vi.fn(),
    getters: {
      'labels/getLabels': [{ title: 'VIP' }, { title: 'Aguardando cliente' }],
    },
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('vuex', async importOriginal => ({
  ...(await importOriginal()),
  useStore: () => mocks.store,
}));

const mountComponent = props =>
  shallowMount(DistributionPolicyForm, {
    props: {
      modelValue: {},
      ...props,
    },
    global: {
      stubs: {
        Banner: true,
        ComboBox: true,
        DurationInput: true,
        Input: true,
        NextButton: true,
        PolicyBusinessHourDay: true,
        RadioCard: true,
        SettingsFieldSection: {
          template: '<section><slot /></section>',
        },
        TagMultiSelectComboBox: true,
        ToggleSwitch: true,
        IbsoftSelect: {
          template: '<select><slot /></select>',
        },
      },
    },
  });

const lastConfig = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('DistributionPolicyForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads labels and forwards policy activation controls', () => {
    const wrapper = mountComponent({
      enabled: false,
      overrideChannelPolicy: false,
      isTeamPolicy: true,
    });

    expect(mocks.store.dispatch).toHaveBeenCalledWith('labels/get');

    wrapper.vm.enabledModel = true;
    wrapper.vm.overrideModel = true;

    expect(wrapper.emitted('update:enabled')).toEqual([[true]]);
    expect(wrapper.emitted('update:overrideChannelPolicy')).toEqual([[true]]);
  });

  it('emits assignment order, priority and capacity as one normalized policy', () => {
    const wrapper = mountComponent();

    wrapper.vm.selectDistributionOption('assignment_order', 'balanced');
    wrapper.vm.selectDistributionOption(
      'conversation_priority',
      'earliest_created'
    );
    wrapper.vm.selectDistributionOption(
      'assignment_limit_mode',
      'open_conversations'
    );
    wrapper.vm.openConversationLimit = 12;
    wrapper.vm.capacityExcludedLabels = ['VIP'];
    wrapper.vm.capacityIgnoreCustomerWaitingEnabled = true;
    wrapper.vm.capacityIgnoreCustomerWaitingMinutes = 180;

    expect(lastConfig(wrapper).distribution).toMatchObject({
      assignment_order: 'balanced',
      conversation_priority: 'earliest_created',
      assignment_limit_mode: 'open_conversations',
      open_conversation_limit: 12,
      capacity_excluded_labels: ['VIP'],
      capacity_ignore_customer_waiting_enabled: true,
      capacity_ignore_customer_waiting_minutes: 180,
    });
  });

  it('keeps assignment-window and per-round limits independently configurable', () => {
    const wrapper = mountComponent();

    wrapper.vm.selectDistributionOption(
      'assignment_limit_mode',
      'assignment_window'
    );
    wrapper.vm.fairDistributionLimit = 20;
    wrapper.vm.fairDistributionWindowInMinutes = 90;
    wrapper.vm.maxRoundLimitEnabled = false;

    expect(lastConfig(wrapper).distribution).toMatchObject({
      assignment_limit_mode: 'assignment_window',
      fair_distribution_limit: 20,
      fair_distribution_window: 5400,
      max_assignments_per_round_enabled: false,
    });
  });

  it('initializes the assignment confirmation message only when enabled', () => {
    const wrapper = mountComponent({
      modelValue: {
        assignment_confirmation: {
          enabled: false,
          message: null,
          only_before_first_reply: true,
        },
      },
    });

    wrapper.vm.assignmentConfirmationEnabled = true;
    wrapper.vm.assignmentConfirmationOnlyBeforeFirstReply = false;

    expect(lastConfig(wrapper).assignment_confirmation).toEqual({
      enabled: true,
      message:
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.DEFAULT_MESSAGE',
      only_before_first_reply: false,
    });
  });

  it('keeps unavailable-agent and outside-hours actions isolated', () => {
    const wrapper = mountComponent({
      allowAfterHoursPolicy: true,
      afterHoursPolicies: [{ id: 9, name: 'Fora do expediente' }],
    });

    wrapper.vm.config.unavailability.no_available_agent = {
      action: 'fallback_team',
      fallback_team_id: 12,
      message: null,
    };
    wrapper.vm.config.unavailability.outside_business_hours = {
      action: 'after_hours_policy',
      fallback_team_id: null,
      message: null,
    };
    wrapper.vm.emitConfig();
    wrapper.vm.afterHoursPolicyModel = 9;

    expect(lastConfig(wrapper).unavailability).toEqual({
      no_available_agent: {
        action: 'fallback_team',
        fallback_team_id: 12,
        message: null,
      },
      outside_business_hours: {
        action: 'after_hours_policy',
        fallback_team_id: null,
        message: null,
      },
    });
    expect(wrapper.emitted('update:afterHoursPolicyId')).toEqual([[9]]);

    wrapper.vm.afterHoursPolicyModel = '';
    expect(wrapper.emitted('update:afterHoursPolicyId').at(-1)).toEqual([null]);
  });

  it('initializes and emits a custom weekly schedule with breaks', () => {
    const wrapper = mountComponent();

    wrapper.vm.config.business_hours.mode = 'custom';
    wrapper.vm.onBusinessHoursModeChange();

    expect(lastConfig(wrapper).business_hours).toMatchObject({
      mode: 'custom',
      timezone: 'America/Sao_Paulo',
    });
    expect(lastConfig(wrapper).business_hours.schedule.length).toBeGreaterThan(
      0
    );

    wrapper.vm.onBusinessHourBreaksUpdate(1, [
      { from: '12:00 PM', to: '01:00 PM', valid: true },
    ]);

    expect(lastConfig(wrapper).business_hours.breaks).toContainEqual({
      day_of_week: 1,
      start_hour: 12,
      start_minutes: 0,
      end_hour: 13,
      end_minutes: 0,
    });
  });

  it('normalizes invalid numeric policy values to the minimum accepted value', () => {
    const wrapper = mountComponent();

    wrapper.vm.onNumberInput('distribution', 'max_assignments_per_round', {
      target: { value: '0' },
    });
    wrapper.vm.onNumberInput(
      'redistribution',
      'first_response_timeout_minutes',
      { target: { value: 'invalid' } }
    );
    wrapper.vm.onNumberInput('supervisor_alert', 'threshold_minutes', {
      target: { value: '-5' },
    });

    const config = lastConfig(wrapper);
    expect(config.distribution.max_assignments_per_round).toBe(1);
    expect(config.redistribution.first_response_timeout_minutes).toBe(1);
    expect(config.supervisor_alert.threshold_minutes).toBe(1);
  });
});
