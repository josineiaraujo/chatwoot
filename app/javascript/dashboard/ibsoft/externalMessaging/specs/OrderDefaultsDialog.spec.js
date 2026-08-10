import { shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { describe, expect, it, vi } from 'vitest';

import OrderDefaultsDialog from '../components/OrderDefaultsDialog.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      Object.entries(values).reduce(
        (message, [valueKey, value]) => message.replace(`{${valueKey}}`, value),
        key
      ),
  }),
}));

const dialogOpenMock = vi.fn();
const messageKeys = [
  'order_pending',
  'order_processing',
  'order_partially_shipped',
  'order_shipped',
  'order_completed',
  'order_canceled',
  'payment_pending',
  'payment_captured',
  'payment_failed',
  'captured_and_completed',
];
const emptyMessages = Object.fromEntries(messageKeys.map(key => [key, '']));

const mountComponent = () =>
  shallowMount(OrderDefaultsDialog, {
    global: {
      stubs: {
        Button: true,
        IbsoftSelect: true,
        ToggleSwitch: true,
        Dialog: {
          name: 'Dialog',
          props: {
            overflowYAuto: {
              type: Boolean,
              default: false,
            },
          },
          setup(props, { slots, expose }) {
            expose({ open: dialogOpenMock, close: vi.fn() });
            return () =>
              h(
                'div',
                { 'data-overflow-y-auto': String(props.overflowYAuto) },
                slots.default?.()
              );
          },
        },
      },
    },
  });

describe('OrderDefaultsDialog', () => {
  it('keeps order settings scrollable on short viewports', () => {
    const wrapper = mountComponent();

    expect(wrapper.find('[data-overflow-y-auto="true"]').exists()).toBe(true);
  });

  it('preserves a configured key unless a replacement is entered', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.open({
      id: 7,
      order_defaults: {
        merchant_name: 'IBSoft Cloud',
        key_type: 'CNPJ',
        key_configured: true,
        key_hint: '****0199',
      },
    });

    wrapper.vm.submit();

    expect(wrapper.emitted('save')).toEqual([
      [
        {
          id: 7,
          payload: {
            order_defaults: {
              merchant_name: 'IBSoft Cloud',
              key_type: 'CNPJ',
              clear_key: false,
              messages: emptyMessages,
            },
          },
        },
      ],
    ]);
    expect(dialogOpenMock).toHaveBeenCalled();
  });

  it('sends a replacement key only when the administrator enters one', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.open({ id: 7, order_defaults: {} });
    wrapper.vm.form.merchant_name = 'IBSoft Cloud';
    wrapper.vm.form.key_type = 'EMAIL';
    wrapper.vm.form.key = 'financeiro@example.com';

    wrapper.vm.submit();

    expect(wrapper.emitted('save')[0][0].payload.order_defaults).toEqual({
      merchant_name: 'IBSoft Cloud',
      key_type: 'EMAIL',
      key: 'financeiro@example.com',
      clear_key: false,
      messages: emptyMessages,
    });
  });

  it('submits the default messages exposed by the instance', async () => {
    const wrapper = mountComponent();
    const messages = Object.fromEntries(
      messageKeys.map(key => [key, `Default ${key} {{reference_id}}`])
    );
    await wrapper.vm.open({
      id: 7,
      order_defaults: {
        messages,
        message_defaults: messages,
      },
    });

    wrapper.vm.form.messages.payment_captured =
      'Payment {{reference_id}} received';
    wrapper.vm.submit();

    expect(
      wrapper.emitted('save')[0][0].payload.order_defaults.messages
        .payment_captured
    ).toBe('Payment {{reference_id}} received');
  });
});
