import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import IntegrationInstructions from '../components/IntegrationInstructions.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const mountComponent = () =>
  shallowMount(IntegrationInstructions, {
    props: {
      publicEndpointUrl: 'https://example.test/chathub-sender/sgp/generico/',
      publicCurlExample: 'curl ordem completa',
      orderUpdateEndpointUrl: 'https://example.test/chathub-sender/sgp/pedido/',
      orderUpdateCurlExample: 'curl atualizacao',
      integrationParameters: [
        { name: 'msg', description: 'Mensagem' },
        { name: 'to', description: 'Destinatário' },
        { name: 'token', description: 'Token' },
      ],
      instanceType: 'sgp_generic',
    },
    global: {
      stubs: {
        Button: true,
      },
    },
  });

describe('IntegrationInstructions', () => {
  it('organizes the supported contract into independent scenarios', () => {
    const wrapper = mountComponent();

    expect(wrapper.vm.scenarios.map(scenario => scenario.id)).toEqual([
      'simple',
      'variables',
      'document',
      'media',
      'buttons',
      'order',
      'order_update',
    ]);
  });

  it('documents document headers and variables with their requirements', () => {
    const wrapper = mountComponent();
    const document = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'document'
    );
    const variables = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'variables'
    );

    expect(document.fields).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          name: 'header_link',
          requirement: 'required',
        }),
        expect.objectContaining({
          name: 'header_filename',
          requirement: 'optional',
        }),
      ])
    );
    expect(variables.fields.map(item => item.name)).toEqual(
      expect.arrayContaining([
        'header.variable.<nome>',
        'header.variable.1',
        'body.<nome>',
        'body.1, body.2, ...',
      ])
    );
  });

  it('documents order payment alternatives and uses the full order example', () => {
    const wrapper = mountComponent();
    const order = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'order'
    );

    expect(order.fields).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          name: 'order.reference_id',
          requirement: 'required',
        }),
        expect.objectContaining({
          name: 'order.payment.pix.code',
          requirement: 'conditional',
        }),
        expect.objectContaining({
          name: 'order.payment.boleto.digitable_line',
          requirement: 'conditional',
        }),
      ])
    );
    expect(order.rules).toEqual(
      expect.arrayContaining([
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.PIX_AND_BOLETO',
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.NO_SECOND_DYNAMIC_BUTTON',
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.BOLETO_ONLY',
      ])
    );
    expect(order.example).toBe('curl ordem completa');
  });

  it('omits the order update scenario when the instance type has no route', () => {
    const wrapper = shallowMount(IntegrationInstructions, {
      props: {
        publicEndpointUrl: 'https://example.test/send',
        publicCurlExample: 'curl send',
      },
      global: {
        stubs: {
          Button: true,
        },
      },
    });

    expect(wrapper.vm.scenarios.map(scenario => scenario.id)).not.toContain(
      'order_update'
    );
  });

  it('uses the IXC envelope in every message scenario', () => {
    const wrapper = shallowMount(IntegrationInstructions, {
      props: {
        instanceType: 'ixc',
        authentication: {
          type: 'username_password',
          username: 'ixc_12',
        },
        publicEndpointUrl: 'https://example.test/chathub-sender/ixc/',
        publicCurlExample: 'curl ordem ixc',
        orderUpdateEndpointUrl:
          'https://example.test/chathub-sender/ixc/pedido/',
        orderUpdateCurlExample:
          "curl --data-urlencode 'user=ixc_12' --data-urlencode 'pw=senha' --data-urlencode 'dest=5575982479788' --data-urlencode 'text=[fatura_id]=9388||[status]=pago'",
        integrationParameters: [
          { name: 'user', description: 'Usuário' },
          { name: 'pw', description: 'Senha' },
          { name: 'dest', description: 'Destinatário' },
          { name: 'text', description: 'Mensagem' },
        ],
      },
      global: {
        stubs: {
          Button: true,
        },
      },
    });

    const simple = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'simple'
    );
    expect(wrapper.vm.requestMethod).toBe(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.IXC_METHOD'
    );
    expect(simple.example).toContain("--data-urlencode 'user=ixc_12'");
    expect(simple.example).toContain(
      "--data-urlencode 'pw=IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PASSWORD_PLACEHOLDER'"
    );
    expect(simple.example).toContain("--data-urlencode 'dest=");
    expect(simple.example).toContain("--data-urlencode 'text=");
    expect(simple.example).not.toContain("--data-urlencode 'msg=");
    const orderUpdate = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'order_update'
    );
    expect(orderUpdate.fields.map(field => field.name)).not.toContain('token');
    expect(orderUpdate.fields.map(field => field.name)).toEqual(
      expect.arrayContaining([
        'user',
        'pw',
        'dest',
        'text',
        'text: [fatura_id]',
      ])
    );
    expect(orderUpdate.rules).toContain(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION_IXC'
    );
    expect(orderUpdate.example).toContain("--data-urlencode 'user=ixc_12'");
    expect(orderUpdate.example).toContain("--data-urlencode 'pw=senha'");
    expect(orderUpdate.example).toContain(
      "--data-urlencode 'dest=5575982479788'"
    );
    expect(orderUpdate.example).toContain(
      "--data-urlencode 'text=[fatura_id]=9388||[status]=pago'"
    );
  });

  it('documents the strict standard POST contract without legacy parameters', () => {
    const wrapper = shallowMount(IntegrationInstructions, {
      props: {
        instanceType: 'standard',
        publicEndpointUrl: 'https://example.test/chathub-sender/',
        publicCurlExample: 'curl ordem padrao',
        orderUpdateEndpointUrl: 'https://example.test/chathub-sender/pedido/',
        orderUpdateCurlExample:
          "curl --request POST --header 'Authorization: Bearer token' --data-raw '[fatura_id]=9388||[status]=pago'",
        integrationParameters: [
          { name: 'Authorization', description: 'Bearer' },
          { name: 'Content-Type', description: 'text/plain' },
          { name: '[to]', description: 'Destinatário' },
          { name: 'body', description: 'Mensagem' },
        ],
      },
      global: {
        stubs: {
          Button: true,
        },
      },
    });

    expect(wrapper.vm.requestMethod).toBe(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.STANDARD_METHOD'
    );
    const simple = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'simple'
    );
    expect(simple.example).toContain('curl --request POST');
    expect(simple.example).toContain("--header 'Authorization: Bearer ");
    expect(simple.example).toContain(
      "--header 'Content-Type: text/plain; charset=UTF-8'"
    );
    expect(simple.example).toContain('||[to]=');
    expect(simple.example).not.toContain('--data-urlencode');

    const orderUpdate = wrapper.vm.scenarios.find(
      scenario => scenario.id === 'order_update'
    );
    expect(orderUpdate.fields.map(field => field.name)).not.toContain('token');
    expect(orderUpdate.rules).toContain(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION_STANDARD'
    );
  });
});
