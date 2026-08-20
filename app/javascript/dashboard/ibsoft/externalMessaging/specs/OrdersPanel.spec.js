import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import externalMessagingAPI from '../api';
import OrdersPanel from '../components/OrdersPanel.vue';

const alertMock = vi.fn();
const dialogOpenMock = vi.fn();
const dialogCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (message, [valueKey, value]) => message.replace(`{${valueKey}}`, value),
        key
      ),
    locale: ref('pt_BR'),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    getOrders: vi.fn(),
    bulkUpdateOrders: vi.fn(),
  },
}));

const updateableOrder = {
  id: 11,
  reference_id: 'invoice-11',
  recipient: '5575982479788',
  order_status: 'pending',
  payment_status: 'pending',
  manually_updateable: true,
  latest_update: null,
  created_at: '2026-07-29T12:00:00.000Z',
};
const blockedOrder = {
  ...updateableOrder,
  id: 12,
  reference_id: 'invoice-12',
  manually_updateable: false,
};

const ordersResponse = {
  data: {
    orders: [updateableOrder, blockedOrder],
    meta: {
      page: 1,
      per_page: 25,
      total: 2,
      updateable_total: 1,
    },
  },
};

const mountComponent = (endpointOverrides = {}) =>
  shallowMount(OrdersPanel, {
    props: {
      endpoint: {
        id: 7,
        retention_days: 30,
        order_defaults_configured: false,
        order_defaults: {},
        order_update_template_ready: false,
        ...endpointOverrides,
      },
    },
    global: {
      stubs: {
        Button: true,
        Spinner: true,
        IbsoftSelect: true,
        BulkOrderUpdateDialog: {
          setup(_props, { expose }) {
            expose({
              open: dialogOpenMock,
              close: dialogCloseMock,
            });
            return () => null;
          },
        },
      },
    },
  });

describe('OrdersPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    externalMessagingAPI.getOrders.mockResolvedValue(ordersResponse);
    externalMessagingAPI.bulkUpdateOrders.mockResolvedValue({
      data: { accepted: true, count: 1 },
    });
  });

  it('loads the first page with the default page size', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(externalMessagingAPI.getOrders).toHaveBeenCalledWith({
      endpoint_id: 7,
      page: 1,
      per_page: 25,
    });
    expect(wrapper.vm.orders).toHaveLength(2);
    expect(wrapper.vm.dateTimeLocale).toBe('pt-BR');
  });

  it('applies recipient and date filters on the server', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    externalMessagingAPI.getOrders.mockClear();

    wrapper.vm.filters.recipient = '(75) 99999-0000';
    wrapper.vm.filters.date_from = '2026-07-01';
    wrapper.vm.applyFilters();
    await flushPromises();

    expect(externalMessagingAPI.getOrders).toHaveBeenCalledWith({
      endpoint_id: 7,
      page: 1,
      per_page: 25,
      recipient: '(75) 99999-0000',
      date_from: '2026-07-01',
    });
  });

  it('keeps order filter controls visually aligned', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    const filterForm = wrapper.get('form');
    const labels = filterForm.findAll('label');
    const inputs = filterForm.findAll('input');
    const selects = filterForm.findAll('ibsoft-select-stub');

    expect(labels).toHaveLength(6);
    expect(
      labels.every(label => label.classes().includes('content-start'))
    ).toBe(true);
    expect(inputs.every(input => input.classes().includes('!mb-0'))).toBe(true);
    expect(selects).toHaveLength(2);
    selects.forEach(select => {
      expect(select.classes()).toEqual(
        expect.arrayContaining([
          'h-10',
          '[&>select]:!h-10',
          '[&>select]:!bg-n-solid-1',
        ])
      );
    });
  });

  it('selects only orders that can still be updated', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.togglePage();

    expect(Array.from(wrapper.vm.selectedIds)).toEqual([11]);
    expect(wrapper.vm.selectedCount).toBe(1);
  });

  it('queues a compact all-filtered bulk update', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.filters.payment_status = 'pending';
    wrapper.vm.applyFilters();
    await flushPromises();
    wrapper.vm.selectAllFiltered();

    await wrapper.vm.submitBulkUpdate({
      order_status: 'completed',
      payment_status: 'captured',
    });

    expect(externalMessagingAPI.bulkUpdateOrders).toHaveBeenCalledWith({
      endpoint_id: 7,
      selection: { mode: 'filter' },
      filters: { payment_status: 'pending' },
      update: {
        order_status: 'completed',
        payment_status: 'captured',
      },
    });
    expect(dialogCloseMock).toHaveBeenCalled();
  });

  it('warns until template-based order updates are configured', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'IBSOFT_EXTERNAL_MESSAGING.ORDERS.TEMPLATE_WARNING_TITLE'
    );
  });

  it('hides the warning after template-based order updates are configured', async () => {
    const wrapper = mountComponent({ order_update_template_ready: true });
    await flushPromises();

    expect(wrapper.text()).not.toContain(
      'IBSOFT_EXTERNAL_MESSAGING.ORDERS.TEMPLATE_WARNING_TITLE'
    );
  });
});
