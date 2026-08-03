import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import WhatsAppTemplatePreview from '../../metaTemplates/components/WhatsAppTemplatePreview.vue';
import TemplatePreview from '../components/TemplatePreview.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

describe('TemplatePreview', () => {
  it('renders the empty state before a template is selected', () => {
    const wrapper = shallowMount(TemplatePreview);

    expect(wrapper.findComponent(WhatsAppTemplatePreview).exists()).toBe(false);
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_PREVIEW_EMPTY'
    );
  });

  it('normalizes the Meta template for the shared WhatsApp preview', () => {
    const wrapper = shallowMount(TemplatePreview, {
      props: {
        template: {
          id: 'template-1',
          name: 'aviso_manutencao',
          language: 'pt_BR',
          category: 'UTILITY',
          parameter_format: 'positional',
          components: [
            {
              type: 'BODY',
              text: 'Olá {{1}}, teremos manutenção.',
              example: { body_text: [['Maria']] },
            },
          ],
        },
      },
    });

    expect(
      wrapper.getComponent(WhatsAppTemplatePreview).props('draft')
    ).toMatchObject({
      name: 'aviso_manutencao',
      language: 'pt_BR',
      category: 'UTILITY',
      model: 'standard',
      body: {
        text: 'Olá {{1}}, teremos manutenção.',
        examples: { 1: 'Maria' },
      },
    });
  });

  it('shows the configured media link in the header preview', () => {
    const wrapper = shallowMount(TemplatePreview, {
      props: {
        template: {
          id: 'template-document',
          name: 'boleto_com_documento',
          language: 'pt_BR',
          category: 'UTILITY',
          components: [
            { type: 'HEADER', format: 'DOCUMENT' },
            { type: 'BODY', text: 'Segue seu documento.' },
          ],
        },
        variables: [
          {
            key: 'header_media_url',
            component_type: 'HEADER',
            parameter_type: 'media',
            media_type: 'document',
            value: 'https://cdn.example.com/fatura%20julho.pdf',
          },
        ],
      },
    });

    expect(
      wrapper.getComponent(WhatsAppTemplatePreview).props('draft').header
    ).toMatchObject({
      format: 'DOCUMENT',
      media_preview_url: 'https://cdn.example.com/fatura%20julho.pdf',
      media_filename: 'fatura julho.pdf',
    });
  });

  it('keeps static and runtime buttons in the shared preview contract', () => {
    const wrapper = shallowMount(TemplatePreview, {
      props: {
        template: {
          id: 'template-buttons',
          name: 'aviso_com_acoes',
          language: 'pt_BR',
          category: 'UTILITY',
          components: [
            { type: 'BODY', text: 'Acompanhe sua solicitação.' },
            {
              type: 'BUTTONS',
              buttons: [
                { type: 'QUICK_REPLY', text: 'Falar com atendimento' },
                {
                  type: 'URL',
                  text: 'Acompanhar pedido',
                  url: 'https://example.com/{{1}}',
                },
                { type: 'COPY_CODE', text: 'Copiar código' },
              ],
            },
          ],
        },
      },
    });

    expect(
      wrapper.getComponent(WhatsAppTemplatePreview).props('draft').buttons
    ).toEqual([
      expect.objectContaining({
        type: 'QUICK_REPLY',
        text: 'Falar com atendimento',
      }),
      expect.objectContaining({
        type: 'URL',
        text: 'Acompanhar pedido',
      }),
      expect.objectContaining({
        type: 'COPY_CODE',
        text: 'Copiar código',
      }),
    ]);
  });
});
