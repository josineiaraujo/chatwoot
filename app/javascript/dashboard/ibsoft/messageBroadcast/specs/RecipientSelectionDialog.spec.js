import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import RecipientSelectionDialog from '../components/RecipientSelectionDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      `${key}${values.count === undefined ? '' : ` ${values.count}`}`,
  }),
}));

const mountComponent = props =>
  mount(RecipientSelectionDialog, {
    props: {
      selectionCount: 10,
      currentPageCount: 10,
      totalCount: 125,
      ...props,
    },
    global: {
      stubs: {
        Dialog: {
          props: ['title'],
          emits: ['close'],
          setup(_, { expose }) {
            expose({ open: vi.fn(), close: vi.fn() });
          },
          template:
            '<section><h1>{{ title }}</h1><slot /><slot name="footer" /></section>',
        },
        Button: {
          props: ['label', 'disabled'],
          emits: ['click'],
          template:
            '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

describe('RecipientSelectionDialog', () => {
  it('shows the selected count and emits page or full-result selection', async () => {
    const wrapper = mountComponent();

    expect(
      wrapper.get('[data-testid="recipient-selection-count"]').text()
    ).toContain('10');

    const buttons = wrapper.findAll('button');
    await buttons[0].trigger('click');
    await buttons[1].trigger('click');

    expect(wrapper.emitted('select-page')).toHaveLength(1);
    expect(wrapper.emitted('select-all')).toHaveLength(1);
  });

  it('requires a name when creating a fixed group', async () => {
    const wrapper = mountComponent({ purpose: 'group', groupName: '' });

    expect(wrapper.find('input').exists()).toBe(true);
    const buttons = wrapper.findAll('button');
    expect(buttons[buttons.length - 1].attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('Clientes ativos');
    expect(wrapper.emitted('update:groupName')).toEqual([['Clientes ativos']]);
  });

  it('adds selected customers to an existing group without asking for a name', () => {
    const wrapper = mountComponent({ purpose: 'group-edit' });

    expect(wrapper.find('input').exists()).toBe(false);
    expect(wrapper.get('h1').text()).toBe(
      'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_EDIT_TITLE'
    );
    expect(wrapper.findAll('button').at(-1).text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.ADD_TO_GROUP'
    );
  });
});
