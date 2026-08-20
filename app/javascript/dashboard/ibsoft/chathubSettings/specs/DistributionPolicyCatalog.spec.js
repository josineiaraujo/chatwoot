import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import DistributionPolicyCatalog from '../components/DistributionPolicyCatalog.vue';
import conversationDistributionAPI from 'dashboard/ibsoft/conversationDistribution/api';
import afterHoursAPI from 'dashboard/ibsoft/afterHours/api';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  store: {
    dispatch: vi.fn(),
    getters: { 'teams/getTeams': [] },
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vuex', async importOriginal => ({
  ...(await importOriginal()),
  useStore: () => mocks.store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => mocks.alert(message),
}));

vi.mock('dashboard/ibsoft/conversationDistribution/api', () => ({
  default: {
    getPolicies: vi.fn(),
    createPolicy: vi.fn(),
    updatePolicy: vi.fn(),
    deletePolicy: vi.fn(),
  },
}));

vi.mock('dashboard/ibsoft/afterHours/api', () => ({
  default: { getPolicies: vi.fn() },
}));

const mountComponent = () =>
  shallowMount(DistributionPolicyCatalog, {
    global: {
      stubs: {
        Button: true,
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        DistributionPolicyCard: true,
        DistributionPolicyForm: true,
        Spinner: true,
      },
    },
  });

describe('DistributionPolicyCatalog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.store.dispatch.mockResolvedValue();
    conversationDistributionAPI.getPolicies.mockResolvedValue({
      data: { policies: [] },
    });
    afterHoursAPI.getPolicies.mockResolvedValue({
      data: { policies: [{ id: 7, name: 'Plantao' }] },
    });
    conversationDistributionAPI.createPolicy.mockResolvedValue({
      data: { id: 15 },
    });
  });

  it('loads after-hours policies together with distribution policies', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(afterHoursAPI.getPolicies).toHaveBeenCalledOnce();
    expect(wrapper.vm.afterHoursPolicies).toEqual([{ id: 7, name: 'Plantao' }]);
  });

  it('persists the selected after-hours policy for the outside-hours action', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.isCreating = true;
    wrapper.vm.policyName = 'Comercial';
    wrapper.vm.afterHoursPolicyId = 7;
    wrapper.vm.config.unavailability.outside_business_hours.action =
      'after_hours_policy';

    await wrapper.vm.savePolicy();

    expect(conversationDistributionAPI.createPolicy).toHaveBeenCalledWith(
      expect.objectContaining({ after_hours_policy_id: 7 })
    );
  });

  it('clears the relationship when another outside-hours action is selected', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.isCreating = true;
    wrapper.vm.policyName = 'Comercial';
    wrapper.vm.afterHoursPolicyId = 7;
    wrapper.vm.config.unavailability.outside_business_hours.action = 'wait';

    await wrapper.vm.savePolicy();

    expect(conversationDistributionAPI.createPolicy).toHaveBeenCalledWith(
      expect.objectContaining({ after_hours_policy_id: null })
    );
  });
});
