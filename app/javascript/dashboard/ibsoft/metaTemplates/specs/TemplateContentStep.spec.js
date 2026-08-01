import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import TemplateContentStep from '../components/TemplateContentStep.vue';
import { createEmptyTemplate } from '../templateModel';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key.split('.').at(-1),
  }),
}));

describe('TemplateContentStep', () => {
  it('renders the button type as a labeled, stable select', () => {
    const draft = createEmptyTemplate();
    draft.buttons = [
      {
        type: 'URL',
        text: 'Abrir rastreio',
        url: 'https://example.com/{{1}}',
        phone_number: '',
        example: '123',
      },
    ];

    const wrapper = shallowMount(TemplateContentStep, {
      props: {
        modelValue: draft,
      },
    });

    const select = wrapper.get('[data-testid="template-button-type-0"]');
    const icon = wrapper.get('[data-testid="template-button-type-icon-0"]');

    expect(select.element.value).toBe('URL');
    expect(select.classes()).toContain('h-10');
    expect(select.classes()).toContain('pe-10');
    expect(icon.classes()).toContain('end-3');
    expect(select.element.closest('label').textContent).toContain(
      'BUTTON_TYPE'
    );
  });
});
