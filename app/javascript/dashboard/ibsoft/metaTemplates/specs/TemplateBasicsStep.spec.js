import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import TemplateBasicsStep from '../components/TemplateBasicsStep.vue';
import { createEmptyTemplate } from '../templateModel';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key.split('.').at(-1),
  }),
}));

const InputStub = {
  inheritAttrs: false,
  props: {
    modelValue: { type: String, default: '' },
  },
  emits: ['update:modelValue', 'blur'],
  template: `
    <input
      data-testid="template-name"
      :value="modelValue"
      v-bind="$attrs"
      @input="$emit('update:modelValue', $event.target.value)"
      @blur="$emit('blur')"
    />
  `,
};

const renderStep = () => {
  const draft = createEmptyTemplate();

  const wrapper = mount(TemplateBasicsStep, {
    props: {
      modelValue: draft,
    },
    global: {
      stubs: {
        ComboBox: true,
        Input: InputStub,
      },
    },
  });

  return { draft, wrapper };
};

describe('TemplateBasicsStep', () => {
  it('sanitizes the model name while typing and trims it on blur', async () => {
    const { draft, wrapper } = renderStep();
    const input = wrapper.get('[data-testid="template-name"]');

    await input.setValue(' Cobrança @ Julho/2026! ');

    expect(draft.name).toBe('cobranca_julho_2026_');
    expect(input.attributes('maxlength')).toBe('512');

    await input.trigger('blur');

    expect(draft.name).toBe('cobranca_julho_2026');
  });
});
