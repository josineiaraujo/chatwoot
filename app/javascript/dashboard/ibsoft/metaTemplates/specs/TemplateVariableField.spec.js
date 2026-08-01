import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import TemplateVariableField from '../components/TemplateVariableField.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) =>
      values.variable ? `${key}:${values.variable}` : key,
  }),
}));

const PopoverStub = {
  emits: ['show', 'hide'],
  methods: {
    hide() {
      this.$emit('hide');
    },
  },
  template: `
    <div>
      <slot />
      <slot name="content" :hide="hide" />
    </div>
  `,
};

const renderField = parameterFormat => {
  const Host = defineComponent({
    components: { TemplateVariableField },
    setup() {
      const text = ref('Olá cliente');
      const examples = ref({});
      return { examples, parameterFormat, text };
    },
    template: `
      <TemplateVariableField
        v-model:text="text"
        v-model:examples="examples"
        field-id="variable-test-field"
        label="Mensagem"
        :parameter-format="parameterFormat"
      >
        <textarea id="variable-test-field" :value="text" />
      </TemplateVariableField>
    `,
  });

  return mount(Host, {
    global: {
      stubs: {
        Popover: PopoverStub,
      },
    },
  });
};

describe('TemplateVariableField', () => {
  it('inserts the next numbered variable at the cursor and shows its example below the field', async () => {
    const wrapper = renderField('positional');
    const textarea = wrapper.get('textarea');
    textarea.element.focus();
    textarea.element.setSelectionRange(4, 11);

    const addButton = wrapper.get('button');
    await addButton.trigger('mousedown');
    await addButton.trigger('click');

    expect(wrapper.vm.text).toBe('Olá {{1}}');
    const examples = wrapper.get(
      '[data-testid="variable-test-field-examples"]'
    );
    expect(examples.find('input').exists()).toBe(true);
    expect(examples.text()).toContain('{{1}}');
    expect(textarea.element.nextElementSibling).toBe(examples.element);
  });

  it('validates and inserts a named variable while keeping examples field-specific', async () => {
    const wrapper = renderField('named');
    const textarea = wrapper.get('textarea');
    textarea.element.focus();
    textarea.element.setSelectionRange(4, 11);

    const buttons = wrapper.findAll('button');
    await buttons[0].trigger('mousedown');
    await wrapper.get('input').setValue('nome_cliente');
    await buttons[1].trigger('click');

    expect(wrapper.vm.text).toBe('Olá {{nome_cliente}}');
    expect(
      wrapper
        .get('[data-testid="variable-test-field-examples"]')
        .attributes('data-testid')
    ).toBe('variable-test-field-examples');
    expect(
      wrapper.get('[data-testid="variable-test-field-examples"]').text()
    ).toContain('{{nome_cliente}}');
  });
});
