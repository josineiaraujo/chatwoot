import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import AfterHoursPolicyCatalog from '../components/AfterHoursPolicyCatalog.vue';
import afterHoursAPI from '../api';

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
    getPolicies: vi.fn(),
    createPolicy: vi.fn(),
    updatePolicy: vi.fn(),
    deletePolicy: vi.fn(),
  },
}));

const policy = {
  id: 7,
  name: 'Plantao',
  enabled: true,
  exit_command: 'sair',
  regular_message: 'Estamos fora do horario.',
  holiday_message: 'Hoje e feriado.',
  exit_confirmation_message: 'Atendimento encerrado.',
  linked_distribution_policies_count: 2,
};

const mountComponent = () =>
  shallowMount(AfterHoursPolicyCatalog, {
    global: {
      stubs: {
        Button: true,
        Dialog: {
          emits: ['close'],
          template: '<div><slot /></div>',
          methods: {
            open: vi.fn(),
            close() {
              this.$emit('close');
            },
          },
        },
        IbsoftDialogHeader: {
          props: ['title', 'closeLabel'],
          emits: ['close'],
          template:
            '<button class="ibsoft-dialog-close" @click="$emit(\'close\')" />',
        },
        Spinner: true,
        ToggleSwitch: true,
      },
    },
  });

describe('AfterHoursPolicyCatalog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    afterHoursAPI.getPolicies.mockResolvedValue({
      data: { policies: [policy] },
    });
    afterHoursAPI.createPolicy.mockResolvedValue({ data: policy });
    afterHoursAPI.updatePolicy.mockResolvedValue({ data: policy });
    afterHoursAPI.deletePolicy.mockResolvedValue({});
  });

  it('loads policies for the current account', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(afterHoursAPI.getPolicies).toHaveBeenCalledOnce();
    expect(wrapper.vm.policies).toEqual([policy]);
  });

  it('closes the editor from its header action', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.editingId = policy.id;
    wrapper.vm.form = { ...policy };

    await wrapper.get('.ibsoft-dialog-close').trigger('click');

    expect(wrapper.vm.editingId).toBeNull();
    expect(wrapper.vm.form.name).toBe('');
  });

  it('creates a policy with all customer-facing messages', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.editingId = null;
    wrapper.vm.form = { ...policy, id: undefined };

    await wrapper.vm.savePolicy();

    expect(afterHoursAPI.createPolicy).toHaveBeenCalledWith(
      expect.objectContaining({
        name: 'Plantao',
        exit_command: 'sair',
        holiday_message: 'Hoje e feriado.',
      })
    );
    expect(afterHoursAPI.getPolicies).toHaveBeenCalledTimes(2);
  });

  it('updates the selected policy instead of creating another one', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.editingId = policy.id;
    wrapper.vm.form = { ...policy, name: 'Plantao atualizado' };

    await wrapper.vm.savePolicy();

    expect(afterHoursAPI.updatePolicy).toHaveBeenCalledWith(
      policy.id,
      expect.objectContaining({ name: 'Plantao atualizado' })
    );
    expect(afterHoursAPI.createPolicy).not.toHaveBeenCalled();
  });

  it('deletes only the selected policy and reloads the catalog', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.deletingPolicy = policy;

    await wrapper.vm.deletePolicy();

    expect(afterHoursAPI.deletePolicy).toHaveBeenCalledWith(policy.id);
    expect(afterHoursAPI.getPolicies).toHaveBeenCalledTimes(2);
  });

  it('requires customer messages only when the policy is enabled', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.form = {
      name: 'Plantao',
      enabled: false,
      exit_command: 'sair',
      regular_message: '',
      holiday_message: '',
      exit_confirmation_message: '',
    };
    expect(wrapper.vm.invalidForm).toBe(false);

    wrapper.vm.form.enabled = true;
    expect(wrapper.vm.invalidForm).toBe(true);

    wrapper.vm.form.regular_message = 'Estamos fora do horario.';
    wrapper.vm.form.holiday_message = 'Hoje e feriado.';
    wrapper.vm.form.exit_confirmation_message = 'Atendimento encerrado.';
    expect(wrapper.vm.invalidForm).toBe(false);
  });

  it('reports load failures and releases the loading state', async () => {
    afterHoursAPI.getPolicies.mockRejectedValue(new Error('request failed'));

    const wrapper = mountComponent();
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith('IBSOFT_AFTER_HOURS.ERRORS.LOAD');
    expect(wrapper.vm.isFetching).toBe(false);
  });

  it('keeps the editor state available when saving fails', async () => {
    afterHoursAPI.createPolicy.mockRejectedValue(new Error('request failed'));
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.form = { ...policy, id: undefined };

    await wrapper.vm.savePolicy();

    expect(afterHoursAPI.getPolicies).toHaveBeenCalledOnce();
    expect(wrapper.vm.form.name).toBe('Plantao');
    expect(wrapper.vm.isSaving).toBe(false);
    expect(mocks.alert).toHaveBeenCalledWith('IBSOFT_AFTER_HOURS.ERRORS.SAVE');
  });

  it('does not issue a delete request without a selected policy', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.deletePolicy();

    expect(afterHoursAPI.deletePolicy).not.toHaveBeenCalled();
  });
});
