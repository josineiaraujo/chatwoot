import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import IbsoftDialogHeader from '../IbsoftDialogHeader.vue';

const mountComponent = props =>
  shallowMount(IbsoftDialogHeader, {
    props: {
      title: 'Editar calendario',
      closeLabel: 'Fechar',
      ...props,
    },
    global: {
      stubs: {
        Button: {
          props: ['ariaLabel', 'title'],
          emits: ['click'],
          template: `
            <button
              type="button"
              :aria-label="ariaLabel"
              :title="title"
              @click="$emit('click')"
            />
          `,
        },
      },
    },
  });

describe('IbsoftDialogHeader', () => {
  it('renders the title and optional description', () => {
    const wrapper = mountComponent({ description: 'Descricao do modal' });

    expect(wrapper.text()).toContain('Editar calendario');
    expect(wrapper.text()).toContain('Descricao do modal');
  });

  it('emits close from the accessible icon button', async () => {
    const wrapper = mountComponent();

    expect(wrapper.get('button').attributes('aria-label')).toBe('Fechar');
    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
