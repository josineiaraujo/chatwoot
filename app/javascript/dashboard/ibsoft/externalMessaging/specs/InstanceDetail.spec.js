import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import { describe, expect, it, vi } from 'vitest';

import InstanceDetail from '../components/InstanceDetail.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    locale: ref('pt_BR'),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const defaultEndpoint = {
  id: 7,
  name: 'ERP principal',
  instance_type: 'sgp_generic',
  inbox_name: 'WhatsApp Cloud',
  token_hint: 'ibext_test...',
  authentication: {
    type: 'token',
    secret_hint: 'ibext_test...',
  },
  active: true,
  rate_limit_per_second: 10,
  deliveries_count: 1,
  retention_days: 30,
  failure_diagnostics_enabled: false,
  order_defaults_configured: false,
  order_defaults: {
    merchant_name: null,
    key_type: null,
    key_configured: false,
    key_hint: null,
  },
};

const mountComponent = (props = {}) => {
  const { endpoint = {}, ...otherProps } = props;

  return shallowMount(InstanceDetail, {
    props: {
      endpoint: { ...defaultEndpoint, ...endpoint },
      typeDefinition: {
        label: 'SGP Genérico',
        description: 'Contrato genérico',
        icon: 'i-lucide-braces',
      },
      deliveryMeta: { page: 1, per_page: 25, total: 0 },
      publicEndpointUrl: 'http://localhost:3000/chathub-sender/sgp/generico/',
      publicCurlExample: 'curl --get',
      orderUpdateEndpointUrl:
        'http://localhost:3000/chathub-sender/sgp/pedido/',
      orderUpdateCurlExample: 'curl --get pedido',
      ...otherProps,
    },
    global: {
      stubs: {
        Button: {
          template: '<button v-bind="$attrs"><slot /></button>',
        },
        Spinner: true,
        IbsoftSelect: true,
        OrdersPanel: true,
      },
    },
  });
};

describe('InstanceDetail', () => {
  it('normalizes Rails locales before formatting dates', () => {
    const wrapper = mountComponent();

    expect(wrapper.vm.dateTimeLocale).toBe('pt-BR');
    expect(() =>
      wrapper.vm.formatDate('2026-07-27T12:00:00.000Z')
    ).not.toThrow();
  });

  it('requests history only when the history tab is opened', () => {
    const wrapper = mountComponent();

    wrapper.vm.selectTab('overview');
    expect(wrapper.emitted('loadHistory')).toBeUndefined();

    wrapper.vm.selectTab('history');
    expect(wrapper.emitted('loadHistory')).toEqual([
      [{ status: '', page: 1, per_page: 25 }],
    ]);
  });

  it('reloads the first history page when the page size changes', () => {
    const wrapper = mountComponent();

    wrapper.vm.historyPageSize = 50;
    wrapper.vm.changeHistoryPageSize();

    expect(wrapper.emitted('loadHistory')).toEqual([
      [{ status: '', page: 1, per_page: 50 }],
    ]);
  });

  it('shows the persisted failure diagnostic in the delivery history', async () => {
    const delivery = {
      id: 31,
      received_at: '2026-08-14T11:10:45.000Z',
      recipient: '5577991046096',
      template_name: 'fatura_disponivel_codigos_pix_boleto',
      status: 'failed',
      meta_message_id: null,
      meta_http_status: 400,
      error_code: '132000',
      error_message: 'body: expected 2 parameters, received 3',
    };
    const wrapper = mountComponent({
      endpoint: { failure_diagnostics_enabled: true },
      deliveries: [delivery],
      deliveryMeta: { page: 1, per_page: 25, total: 1 },
      historyLoaded: true,
    });

    wrapper.vm.selectTab('history');
    await wrapper.vm.$nextTick();

    const diagnostic = wrapper.get('[data-testid="delivery-diagnostic"]');
    expect(diagnostic.text()).toContain(delivery.error_message);
    expect(diagnostic.attributes('title')).toContain(delivery.error_message);
  });

  it('keeps the original history layout when failure diagnostics are disabled', async () => {
    const wrapper = mountComponent({
      deliveries: [
        {
          id: 31,
          status: 'failed',
          error_code: '132000',
          error_message: 'Template rejected',
        },
      ],
      deliveryMeta: { page: 1, per_page: 25, total: 1 },
      historyLoaded: true,
    });

    wrapper.vm.selectTab('history');
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="delivery-diagnostic"]').exists()).toBe(
      false
    );
  });

  it('shows the order section and delegates configuration to the parent', async () => {
    const wrapper = mountComponent();

    expect(wrapper.vm.tabs.map(tab => tab.id)).toEqual([
      'overview',
      'orders',
      'instructions',
      'history',
    ]);
    wrapper.vm.selectTab('orders');
    await wrapper.vm.$nextTick();

    const ordersPanel = wrapper.findComponent({ name: 'OrdersPanel' });
    expect(ordersPanel.exists()).toBe(true);
    ordersPanel.vm.$emit('configureOrders', wrapper.props('endpoint'));
    expect(wrapper.emitted('configureOrders')).toEqual([
      [wrapper.props('endpoint')],
    ]);
  });

  it('delegates integration documentation to the dedicated guide', async () => {
    const wrapper = mountComponent();

    wrapper.vm.selectTab('instructions');
    await wrapper.vm.$nextTick();

    const guide = wrapper.findComponent({ name: 'IntegrationInstructions' });
    expect(guide.exists()).toBe(true);
    expect(guide.props('publicEndpointUrl')).toBe(
      'http://localhost:3000/chathub-sender/sgp/generico/'
    );
    expect(guide.props('orderUpdateEndpointUrl')).toBe(
      'http://localhost:3000/chathub-sender/sgp/pedido/'
    );
    expect(guide.props('instanceType')).toBe('sgp_generic');
  });

  it('keeps shared order management available for IXC instances', async () => {
    const wrapper = mountComponent({
      endpoint: {
        id: 8,
        name: 'IXC principal',
        instance_type: 'ixc',
        inbox_name: 'WhatsApp Cloud',
        authentication: {
          type: 'username_password',
          username: 'ixc_8',
          secret_hint: 'ibext_ixc...',
        },
        active: true,
        rate_limit_per_second: 10,
        deliveries_count: 0,
        retention_days: 30,
        order_defaults: {},
      },
      orderUpdateEndpointUrl: '',
      orderUpdateCurlExample: '',
    });

    expect(wrapper.vm.tabs.map(tab => tab.id)).toEqual([
      'overview',
      'orders',
      'instructions',
      'history',
    ]);
    wrapper.vm.selectTab('instructions');
    await wrapper.vm.$nextTick();

    const guide = wrapper.findComponent({ name: 'IntegrationInstructions' });
    expect(guide.props('instanceType')).toBe('ixc');
    expect(guide.props('authentication')).toEqual(
      expect.objectContaining({ username: 'ixc_8' })
    );
  });

  it('opens credential management without requesting token rotation', async () => {
    const wrapper = mountComponent();

    await wrapper
      .find('[aria-label="IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREDENTIALS"]')
      .trigger('click');

    expect(wrapper.emitted('credentials')).toEqual([
      [wrapper.props('endpoint')],
    ]);
    expect(wrapper.emitted('rotate')).toBeUndefined();
  });
});
