import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import IbsoftSelect from '../IbsoftSelect.vue';

const mountComponent = (modelValue, props = {}) =>
  mount(IbsoftSelect, {
    props: { modelValue, ...props },
    slots: {
      default: `
        <option value="">Selecione</option>
        <option value="wait">Aguardar</option>
      `,
    },
    global: {
      mocks: {
        $t: key => key,
      },
    },
  });

describe('IbsoftSelect', () => {
  it('shows a visible clear action when a value is selected', () => {
    const wrapper = mountComponent('wait');
    const clearButton = wrapper.get('button');

    expect(clearButton.classes()).toEqual(
      expect.arrayContaining(['size-6', 'bg-n-alpha-2', 'text-n-slate-12'])
    );
    expect(clearButton.get('[aria-hidden="true"]').classes()).toEqual(
      expect.arrayContaining(['i-lucide-x', 'block', 'size-4'])
    );
    expect(wrapper.get('select').classes()).toContain('pe-20');
  });

  it('clears the selected value without changing the select contract', async () => {
    const wrapper = mountComponent('wait');

    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['']);
  });

  it('does not render the clear action for an empty value', () => {
    const wrapper = mountComponent('');

    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.get('select').classes()).not.toContain('pe-20');
  });

  it('does not render the clear action for a required selection', () => {
    const wrapper = mountComponent('wait', { clearable: false });

    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.get('select').classes()).not.toContain('pe-20');
  });
});
