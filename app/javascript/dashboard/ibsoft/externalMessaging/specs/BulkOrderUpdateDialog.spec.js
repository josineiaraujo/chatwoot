import { shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { describe, expect, it, vi } from 'vitest';

import BulkOrderUpdateDialog from '../components/BulkOrderUpdateDialog.vue';

const dialogOpenMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

const mountComponent = () =>
  shallowMount(BulkOrderUpdateDialog, {
    global: {
      stubs: {
        Button: true,
        IbsoftSelect: true,
        Dialog: {
          setup(_props, { slots, expose }) {
            expose({ open: dialogOpenMock, close: vi.fn() });
            return () => h('div', [slots.default?.(), slots.footer?.()].flat());
          },
        },
      },
    },
  });

describe('BulkOrderUpdateDialog', () => {
  it('requires at least one status change', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.open({ count: 3, allFiltered: false });

    wrapper.vm.submit();

    expect(wrapper.vm.isInvalid).toBe(true);
    expect(wrapper.emitted('save')).toBeUndefined();
  });

  it('rejects canceled orders with a captured payment', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.open({ count: 3, allFiltered: true });
    wrapper.vm.form.order_status = 'canceled';
    wrapper.vm.form.payment_status = 'captured';

    wrapper.vm.submit();

    expect(wrapper.vm.isInvalid).toBe(true);
    expect(wrapper.emitted('save')).toBeUndefined();
  });

  it('emits a valid partial status update', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.open({ count: 3, allFiltered: false });
    wrapper.vm.form.payment_status = 'captured';

    wrapper.vm.submit();

    expect(wrapper.emitted('save')).toEqual([
      [{ order_status: null, payment_status: 'captured' }],
    ]);
  });
});
