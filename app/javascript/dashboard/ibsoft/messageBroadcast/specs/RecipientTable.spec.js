import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import RecipientTable from '../components/RecipientTable.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (text, [name, value]) => text.replace(`{${name}}`, value),
        key
      ),
  }),
}));

const recipient = (id, deliverable = true) => ({
  external_id: String(id),
  name: `Cliente ${id}`,
  city_name: 'Salvador',
  state: 'BA',
  phone_selection: {
    primary_phone: deliverable
      ? `+557199999${String(id).padStart(4, '0')}`
      : '',
    fallback_phone: '',
    deliverable,
  },
});

const mountTable = recipients =>
  mount(RecipientTable, {
    props: { recipients, canContinue: recipients.length > 0 },
    global: {
      stubs: {
        Button: {
          props: ['label', 'title', 'ariaLabel', 'disabled'],
          emits: ['click'],
          template:
            '<button :disabled="disabled" :title="title" :aria-label="ariaLabel" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Input: {
          props: ['modelValue', 'label', 'placeholder'],
          emits: ['update:modelValue'],
          template:
            '<label>{{ label }}<input :value="modelValue" :placeholder="placeholder" @input="$emit(\'update:modelValue\', $event.target.value)" /></label>',
        },
        PaginationFooter: {
          props: ['currentPage', 'totalItems', 'itemsPerPage'],
          emits: ['update:currentPage'],
          template:
            '<button data-testid="next-page" @click="$emit(\'update:currentPage\', 2)">next</button>',
        },
      },
    },
  });

describe('RecipientTable', () => {
  it('shows ten recipients per page and changes pages without expanding the list', async () => {
    const recipients = Array.from({ length: 25 }, (_, index) =>
      recipient(index + 1)
    );
    const wrapper = mountTable(recipients);

    expect(wrapper.findAll('tbody tr')).toHaveLength(10);
    expect(wrapper.text()).toContain('Cliente 1');

    await wrapper.get('[data-testid="next-page"]').trigger('click');

    expect(wrapper.findAll('tbody tr')).toHaveLength(10);
    expect(wrapper.text()).toContain('Cliente 11');

    wrapper.vm.pageSize = 25;
    await flushPromises();

    expect(wrapper.findAll('tbody tr')).toHaveLength(25);
  });

  it('searches recipients and filters entries without a valid phone', async () => {
    const wrapper = mountTable([
      recipient(1),
      { ...recipient(2, false), name: 'Cliente sem telefone' },
    ]);

    wrapper.vm.searchQuery = 'sem telefone';
    await flushPromises();
    expect(wrapper.findAll('tbody tr')).toHaveLength(1);

    wrapper.vm.searchQuery = '';
    wrapper.vm.phoneFilter = 'unavailable';
    await flushPromises();

    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    expect(wrapper.text()).toContain('Cliente sem telefone');
  });

  it('normalizes edited phone numbers and emits remove actions', async () => {
    const customer = recipient(1);
    const wrapper = mountTable([customer]);

    wrapper.vm.startEditing(customer);
    wrapper.vm.editForm.primaryPhone = '(71) 98888-7777';
    wrapper.vm.editForm.fallbackPhone = '(71) 97777-6666';
    wrapper.vm.saveEditing(customer);

    expect(wrapper.emitted('update')[0][0].phone_selection).toEqual(
      expect.objectContaining({
        primary_phone: '+5571988887777',
        fallback_phone: '+5571977776666',
        deliverable: true,
      })
    );

    await wrapper
      .get('[aria-label="IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.REMOVE"]')
      .trigger('click');

    expect(wrapper.emitted('remove')).toEqual([[customer]]);
  });
});
