import { mount } from '@vue/test-utils';
import { h } from 'vue';
import { describe, expect, it, vi } from 'vitest';

import InstanceEditorDialog from '../components/InstanceEditorDialog.vue';

const dialogOpenMock = vi.fn();
const dialogCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

const mountComponent = () =>
  mount(InstanceEditorDialog, {
    props: {
      inboxes: [{ id: 3, name: 'WhatsApp Cloud' }],
      instanceTypes: [
        {
          value: 'sgp_generic',
          icon: 'i-lucide-braces',
          label: 'SGP Genérico',
          description: 'Contrato genérico',
        },
      ],
    },
    global: {
      stubs: {
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Dialog: {
          name: 'Dialog',
          props: {
            overflowYAuto: {
              type: Boolean,
              default: false,
            },
          },
          setup(props, { slots, expose }) {
            expose({
              open: dialogOpenMock,
              close: dialogCloseMock,
            });
            return () =>
              h(
                'div',
                { 'data-overflow-y-auto': String(props.overflowYAuto) },
                [slots.default?.(), slots.footer?.()].flat()
              );
          },
        },
        ToggleSwitch: true,
        IbsoftSelect: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><slot /></select>',
        },
      },
    },
  });

describe('InstanceEditorDialog', () => {
  it('keeps the editor scrollable on short viewports', () => {
    const wrapper = mountComponent();

    expect(wrapper.find('[data-overflow-y-auto="true"]').exists()).toBe(true);
  });

  it('starts creation with type selection and emits the selected type', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open();
    expect(wrapper.vm.step).toBe('type');

    wrapper.vm.step = 'configuration';
    wrapper.vm.form.name = 'Financeiro';
    wrapper.vm.form.inbox_id = 3;
    wrapper.vm.submit();

    expect(wrapper.emitted('save')).toEqual([
      [
        {
          id: null,
          payload: {
            instance_type: 'sgp_generic',
            name: 'Financeiro',
            inbox_id: 3,
            active: true,
            allow_order_resends: true,
            failure_diagnostics_enabled: false,
            rate_limit_per_second: 10,
            retention_days: 30,
          },
        },
      ],
    ]);
  });

  it('keeps type and channel immutable while editing', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.open({
      id: 7,
      name: 'ERP principal',
      instance_type: 'sgp_generic',
      inbox_id: 3,
      active: true,
      allow_order_resends: false,
      failure_diagnostics_enabled: true,
      rate_limit_per_second: 10,
      retention_days: 45,
    });
    wrapper.vm.form.name = 'ERP atualizado';
    wrapper.vm.submit();

    expect(wrapper.vm.isEditing).toBe(true);
    expect(wrapper.emitted('save')).toEqual([
      [
        {
          id: 7,
          payload: {
            name: 'ERP atualizado',
            active: true,
            allow_order_resends: false,
            failure_diagnostics_enabled: true,
            rate_limit_per_second: 10,
            retention_days: 45,
          },
        },
      ],
    ]);
  });
});
