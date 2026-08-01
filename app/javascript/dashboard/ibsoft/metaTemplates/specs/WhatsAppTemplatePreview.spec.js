import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import WhatsAppTemplatePreview from '../components/WhatsAppTemplatePreview.vue';
import { createEmptyTemplate } from '../templateModel';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'pt_BR' },
    t: key => key.split('.').at(-1),
  }),
}));

const createDraft = overrides => {
  const base = createEmptyTemplate();

  return {
    ...base,
    ...overrides,
    header: { ...base.header, ...overrides.header },
    body: { ...base.body, ...overrides.body },
    footer: { ...base.footer, ...overrides.footer },
    special: { ...base.special, ...overrides.special },
    authentication: {
      ...base.authentication,
      ...overrides.authentication,
    },
  };
};

const renderPreview = draft =>
  mount(WhatsAppTemplatePreview, {
    props: { draft },
  });

describe('WhatsAppTemplatePreview', () => {
  it('renders a standard message with media, timestamp and generic actions', () => {
    const wrapper = renderPreview(
      createDraft({
        model: 'standard',
        header: { format: 'IMAGE' },
        body: { text: 'Mensagem padrão' },
        buttons: [{ type: 'URL', text: 'Abrir site' }],
      })
    );

    expect(wrapper.get('[data-testid="preview-message"]').exists()).toBe(true);
    expect(wrapper.get('.i-lucide-image').exists()).toBe(true);
    expect(wrapper.get('[data-testid="preview-timestamp"]').text()).not.toBe(
      ''
    );
    expect(wrapper.get('[data-testid="preview-action"]').text()).toContain(
      'Abrir site'
    );
  });

  it('renders the catalog product card and its exclusive action', () => {
    const wrapper = renderPreview(
      createDraft({
        category: 'MARKETING',
        model: 'catalog',
        body: { text: 'Conheça nossos produtos' },
        special: { button_text: 'Ver catálogo' },
      })
    );

    expect(wrapper.get('[data-testid="preview-catalog-card"]').exists()).toBe(
      true
    );
    expect(
      wrapper.get('[data-testid="preview-special-action"]').text()
    ).toContain('Ver catálogo');
    expect(wrapper.find('[data-testid="preview-action"]').exists()).toBe(false);
  });

  it('renders order reference, document and payment summary', () => {
    const wrapper = renderPreview(
      createDraft({
        model: 'order_details',
        header: {
          format: 'DOCUMENT',
          media_filename: 'fatura-123.pdf',
        },
        body: { text: 'Confira os dados do pagamento' },
      })
    );

    const orderDetails = wrapper.get('[data-testid="preview-order-details"]');
    const orderActions = wrapper.findAll(
      '[data-testid="preview-order-action"]'
    );

    expect(orderDetails.text()).toContain('ORDER_REFERENCE');
    expect(orderDetails.text()).toContain('fatura-123.pdf');
    expect(orderDetails.text()).toContain('PAYMENT_METHOD');
    expect(orderDetails.text()).toContain('ORDER_TOTAL');
    expect(orderDetails.get('.i-lucide-barcode').exists()).toBe(true);
    expect(orderActions).toHaveLength(2);
    expect(orderActions[0].get('.i-lucide-copy').exists()).toBe(true);
    expect(orderActions[0].text()).toBe('COPY_PIX_CODE');
    expect(orderActions[1].get('.i-lucide-barcode').exists()).toBe(true);
    expect(orderActions[1].text()).toBe('COPY_BARCODE');
    expect(
      wrapper.find('[data-testid="preview-special-action"]').exists()
    ).toBe(false);
  });

  it('renders the call permission panel with the semantic action', () => {
    const wrapper = renderPreview(
      createDraft({
        model: 'call_permission_request',
        body: { text: 'Escolha se podemos ligar para você.' },
      })
    );

    expect(
      wrapper.get('[data-testid="preview-call-permission"]').text()
    ).toContain('Escolha se podemos ligar para você.');
    expect(
      wrapper.get('[data-testid="preview-special-action"]').classes()
    ).toContain('text-n-teal-11');
  });

  it('renders an order status as a simple operational message', () => {
    const wrapper = renderPreview(
      createDraft({
        model: 'order_status',
        body: { text: 'Seu pedido foi enviado.' },
      })
    );

    expect(wrapper.get('[data-testid="preview-order-status"]').text()).toBe(
      'ORDER_STATUS'
    );
    expect(wrapper.text()).toContain('Seu pedido foi enviado.');
    expect(
      wrapper.find('[data-testid="preview-special-action"]').exists()
    ).toBe(false);
  });
});
