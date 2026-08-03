import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import GroupEditorDialog from '../components/GroupEditorDialog.vue';

const dialogCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

const member = {
  external_id: '4797',
  name: 'Cliente IXC',
  phone_selection: {
    primary_phone: '+5571999999999',
    fallback_phone: '',
    deliverable: true,
  },
};

const mountComponent = props =>
  mount(GroupEditorDialog, {
    props: {
      groupName: 'Clientes ativos',
      members: [member],
      ...props,
    },
    global: {
      stubs: {
        Dialog: {
          props: ['title'],
          emits: ['close'],
          setup(_, { expose }) {
            expose({ open: vi.fn(), close: dialogCloseMock });
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
        RecipientTable: {
          props: ['recipients', 'showContinue', 'emptyMessage'],
          emits: ['remove', 'update'],
          template:
            '<div data-testid="group-members" :data-member-count="recipients.length" :data-show-continue="showContinue" />',
        },
        Spinner: true,
      },
    },
  });

describe('GroupEditorDialog', () => {
  it('shows members only inside the editor and exposes the editing actions', async () => {
    const wrapper = mountComponent();

    expect(wrapper.get('[data-testid="group-members"]').attributes()).toEqual(
      expect.objectContaining({
        'data-member-count': '1',
        'data-show-continue': 'false',
      })
    );

    await wrapper.get('input').setValue('Clientes prioritários');
    expect(wrapper.emitted('update:groupName')).toEqual([
      ['Clientes prioritários'],
    ]);

    const addButton = wrapper
      .findAll('button')
      .find(button => button.text().endsWith('.ADD_MEMBERS'));
    const saveButton = wrapper
      .findAll('button')
      .find(button => button.text().endsWith('.SAVE'));

    await addButton.trigger('click');
    await saveButton.trigger('click');

    expect(wrapper.emitted('add')).toHaveLength(1);
    expect(wrapper.emitted('save')).toHaveLength(1);
  });

  it('blocks saving while the group is loading or has no name', () => {
    const loadingWrapper = mountComponent({ isLoading: true });
    const emptyNameWrapper = mountComponent({ groupName: '   ' });

    expect(loadingWrapper.vm.disableSave).toBe(true);
    expect(emptyNameWrapper.vm.disableSave).toBe(true);
  });
});
