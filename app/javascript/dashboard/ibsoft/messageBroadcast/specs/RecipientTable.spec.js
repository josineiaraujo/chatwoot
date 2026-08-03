import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import RecipientTable from '../components/RecipientTable.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      if (key.endsWith('PRIMARY_PHONE_VALUE')) {
        return `Principal: ${values.phone}`;
      }
      if (key.endsWith('FALLBACK_PHONE_VALUE')) {
        return `Alternativo: ${values.phone}`;
      }

      return key;
    },
  }),
}));

const recipient = {
  external_id: '4797',
  name: 'Cliente IXC',
  city_name: 'Salvador',
  state: 'BA',
  phone_selection: {
    primary_phone: '+5571999999999',
    fallback_phone: '+5571888888888',
    deliverable: true,
  },
};

const mountComponent = (props = {}) =>
  shallowMount(RecipientTable, {
    props: {
      recipients: [recipient],
      canContinue: true,
      ...props,
    },
    global: {
      stubs: {
        Button: true,
        Input: true,
        IbsoftSelect: true,
        PageSizeSelect: true,
        PaginationFooter: true,
      },
    },
  });

describe('RecipientTable', () => {
  it('identifies the primary and fallback phone numbers in priority order', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('Principal: +5571999999999');
    expect(wrapper.text()).toContain('Alternativo: +5571888888888');
    expect(wrapper.text().indexOf('Principal:')).toBeLessThan(
      wrapper.text().indexOf('Alternativo:')
    );
  });

  it('normalizes edited numbers and removes a duplicated fallback', () => {
    const wrapper = mountComponent();

    wrapper.vm.startEditing(recipient);
    wrapper.vm.editForm.primaryPhone = '(71) 99999-9999';
    wrapper.vm.editForm.fallbackPhone = '+55 71 99999-9999';
    wrapper.vm.saveEditing(recipient);

    expect(wrapper.emitted('update')).toEqual([
      [
        expect.objectContaining({
          phone_selection: expect.objectContaining({
            primary_phone: '+5571999999999',
            fallback_phone: '',
            deliverable: true,
            reason: 'manual_override',
          }),
        }),
      ],
    ]);
  });

  it('supports an editor-only empty state without a continue action', () => {
    const wrapper = mountComponent({
      recipients: [],
      showContinue: false,
      emptyMessage: 'Grupo sem destinatários',
    });

    expect(wrapper.text()).toContain('Grupo sem destinatários');
    expect(wrapper.findComponent({ name: 'Button' }).exists()).toBe(false);
  });
});
