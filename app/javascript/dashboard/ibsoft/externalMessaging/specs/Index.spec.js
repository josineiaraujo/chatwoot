import { flushPromises, shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import externalMessagingAPI from '../api';
import ExternalMessagingIndex from '../views/Index.vue';

const alertMock = vi.fn();
const editorOpenMock = vi.fn();
const editorCloseMock = vi.fn();
const tokenOpenMock = vi.fn();
const orderDefaultsOpenMock = vi.fn();
const orderDefaultsCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (message, [valueKey, value]) => message.replace(`{${valueKey}}`, value),
        key
      ),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    getEndpoints: vi.fn(),
    createEndpoint: vi.fn(),
    updateEndpoint: vi.fn(),
    deactivateEndpoint: vi.fn(),
    rotateToken: vi.fn(),
    getDeliveries: vi.fn(),
  },
}));

const endpoint = {
  id: 7,
  name: 'ERP principal',
  instance_type: 'sgp_generic',
  integration_family: 'sgp',
  public_path: '/chathub-sender/sgp/generico/',
  order_update_path: '/chathub-sender/sgp/pedido/',
  inbox_id: 3,
  inbox_name: 'WhatsApp Cloud',
  token_hint: 'ibext_test...',
  authentication: {
    type: 'token',
    secret_hint: 'ibext_test...',
  },
  active: true,
  rate_limit_per_second: 10,
  retention_days: 30,
  deliveries_count: 1,
  order_defaults_configured: false,
  order_defaults: {
    merchant_name: null,
    key_type: null,
    key_configured: false,
    key_hint: null,
  },
};

const endpointsResponse = {
  data: {
    endpoints: [endpoint],
    inboxes: [{ id: 3, name: 'WhatsApp Cloud' }],
  },
};

const deliveriesResponse = {
  data: {
    deliveries: [
      {
        id: 12,
        endpoint_name: 'ERP principal',
        recipient: '5575982479788',
        template_name: 'invoice_ready',
        status: 'accepted',
        meta_message_id: 'wamid.external-12',
        received_at: '2026-07-27T12:00:00.000Z',
      },
    ],
    meta: { page: 1, per_page: 25, total: 1 },
  },
};

const mountComponent = () =>
  shallowMount(ExternalMessagingIndex, {
    global: {
      stubs: {
        Button: true,
        Spinner: true,
        InstanceCard: {
          props: ['endpoint'],
          template: '<article>{{ endpoint.name }}</article>',
        },
        InstanceDetail: {
          props: ['endpoint'],
          template: '<section>{{ endpoint.name }}</section>',
        },
        InstanceEditorDialog: {
          setup(_props, { expose }) {
            expose({
              open: editorOpenMock,
              close: editorCloseMock,
            });
            return () => h('div');
          },
        },
        OrderDefaultsDialog: {
          setup(_props, { expose }) {
            expose({
              open: orderDefaultsOpenMock,
              close: orderDefaultsCloseMock,
            });
            return () => h('div');
          },
        },
        Dialog: {
          setup(_props, { slots, expose }) {
            expose({
              open: tokenOpenMock,
              close: vi.fn(),
            });
            return () => h('div', slots.default?.());
          },
        },
      },
    },
  });

describe('ExternalMessagingIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    externalMessagingAPI.getEndpoints.mockResolvedValue(endpointsResponse);
    externalMessagingAPI.getDeliveries.mockResolvedValue(deliveriesResponse);
    externalMessagingAPI.createEndpoint.mockResolvedValue({
      data: { id: 8, token: 'ibext_new-token' },
    });
    externalMessagingAPI.updateEndpoint.mockResolvedValue({ data: endpoint });
  });

  it('loads only the instance catalog on entry', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(externalMessagingAPI.getEndpoints).toHaveBeenCalledOnce();
    expect(externalMessagingAPI.getDeliveries).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('ERP principal');
    expect(wrapper.vm.instanceTypes).toEqual([
      expect.objectContaining({
        value: 'sgp_generic',
        label: 'IBSOFT_EXTERNAL_MESSAGING.TYPES.SGP_GENERIC.NAME',
      }),
      expect.objectContaining({
        value: 'ixc',
        label: 'IBSOFT_EXTERNAL_MESSAGING.TYPES.IXC.NAME',
      }),
    ]);
    expect(wrapper.vm.publicEndpointUrl).toBe('');
  });

  it('loads history only for the instance being viewed', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.openInstance(endpoint);
    expect(wrapper.vm.publicEndpointUrl).toBe(
      'http://localhost:3000/chathub-sender/sgp/generico/'
    );
    expect(wrapper.vm.orderUpdateEndpointUrl).toBe(
      'http://localhost:3000/chathub-sender/sgp/pedido/'
    );
    expect(wrapper.vm.orderUpdateCurlExample).toContain(
      "--data-urlencode 'status=pago'"
    );
    await wrapper.vm.fetchDeliveries({
      status: 'accepted',
      page: 2,
      per_page: 25,
    });

    expect(wrapper.vm.selectedEndpoint).toEqual(endpoint);
    expect(externalMessagingAPI.getDeliveries).toHaveBeenCalledWith({
      endpoint_id: 7,
      status: 'accepted',
      page: 2,
      per_page: 25,
    });
    expect(wrapper.vm.historyLoaded).toBe(true);
  });

  it('creates a typed instance and reveals its token only after saving', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    const payload = {
      instance_type: 'sgp_generic',
      name: 'ERP financeiro',
      inbox_id: 3,
      active: true,
      rate_limit_per_second: 20,
      retention_days: 30,
    };
    await wrapper.vm.saveEndpoint({ id: null, payload });

    expect(externalMessagingAPI.createEndpoint).toHaveBeenCalledWith(payload);
    expect(editorCloseMock).toHaveBeenCalled();
    expect(tokenOpenMock).toHaveBeenCalled();
    expect(wrapper.vm.selectedEndpointId).toBe(8);
    expect(wrapper.vm.revealedCredentials).toEqual({
      type: 'token',
      token: 'ibext_new-token',
    });
    expect(wrapper.vm.curlExample).toContain(
      "--data-urlencode 'token=ibext_new-token'"
    );
    expect(wrapper.vm.curlExample).toContain('[order.payment.pix.code]=');
    expect(wrapper.vm.curlExample).toContain(
      '[order.payment.boleto.digitable_line]='
    );
    expect(wrapper.vm.curlExample).not.toContain('Authorization');
  });

  it('creates an IXC instance and documents its exact envelope', async () => {
    const ixcEndpoint = {
      ...endpoint,
      id: 8,
      name: 'IXC principal',
      instance_type: 'ixc',
      integration_family: 'ixc',
      public_path: '/chathub-sender/ixc/',
      order_update_path: '/chathub-sender/ixc/pedido/',
      authentication: {
        type: 'username_password',
        username: 'ixc_8',
        secret_hint: 'ibext_ixc...',
      },
    };
    externalMessagingAPI.getEndpoints.mockResolvedValue({
      data: {
        endpoints: [endpoint, ixcEndpoint],
        inboxes: endpointsResponse.data.inboxes,
      },
    });
    externalMessagingAPI.createEndpoint.mockResolvedValue({
      data: {
        ...ixcEndpoint,
        credentials: {
          type: 'username_password',
          username: 'ixc_8',
          password: 'ibext_ixc-password',
        },
      },
    });
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.saveEndpoint({
      id: null,
      payload: {
        instance_type: 'ixc',
        name: 'IXC principal',
        inbox_id: 3,
      },
    });

    expect(wrapper.vm.revealedCredentials).toEqual({
      type: 'username_password',
      username: 'ixc_8',
      password: 'ibext_ixc-password',
    });
    expect(wrapper.vm.isRevealedIxc).toBe(true);
    expect(wrapper.vm.integrationParameters.map(item => item.name)).toEqual([
      'user',
      'pw',
      'dest',
      'text',
    ]);
    expect(wrapper.vm.curlExample).toContain("--data-urlencode 'user=ixc_8'");
    expect(wrapper.vm.curlExample).toContain(
      "--data-urlencode 'pw=ibext_ixc-password'"
    );
    expect(wrapper.vm.curlExample).toContain("--data-urlencode 'dest=");
    expect(wrapper.vm.curlExample).toContain("--data-urlencode 'text=");
    expect(wrapper.vm.curlExample).not.toContain("--data-urlencode 'token=");
    expect(wrapper.vm.orderUpdateEndpointUrl).toBe(
      'http://localhost:3000/chathub-sender/ixc/pedido/'
    );
    expect(wrapper.vm.orderUpdateCurlExample).toContain(
      "--data-urlencode 'user=ixc_8'"
    );
    expect(wrapper.vm.orderUpdateCurlExample).toContain(
      "--data-urlencode 'pw=IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PASSWORD_PLACEHOLDER'"
    );
    expect(wrapper.vm.orderUpdateCurlExample).toContain(
      "--data-urlencode 'dest=IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.RECIPIENT'"
    );
    expect(wrapper.vm.orderUpdateCurlExample).toContain(
      "--data-urlencode 'text=[fatura_id]=IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.ORDER_REFERENCE||[status]=pago'"
    );
  });

  it('updates order defaults in the selected instance', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    wrapper.vm.openInstance(endpoint);
    const payload = {
      order_defaults: {
        merchant_name: 'IBSoft Cloud',
        key_type: 'CNPJ',
        key: '12345678000199',
        clear_key: false,
      },
    };

    await wrapper.vm.saveOrderDefaults({ id: 7, payload });

    expect(externalMessagingAPI.updateEndpoint).toHaveBeenCalledWith(
      7,
      payload
    );
    expect(orderDefaultsCloseMock).toHaveBeenCalled();
    expect(externalMessagingAPI.getEndpoints).toHaveBeenCalledTimes(2);
  });
});
