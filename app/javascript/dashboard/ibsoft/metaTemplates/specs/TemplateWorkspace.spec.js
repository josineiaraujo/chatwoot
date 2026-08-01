import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import metaTemplatesAPI from '../api';
import TemplateWorkspace from '../components/TemplateWorkspace.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key.split('.').at(-1),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('../api', () => ({
  default: {
    createTemplate: vi.fn(),
    updateTemplate: vi.fn(),
  },
}));

const ButtonStub = {
  props: {
    isLoading: { type: Boolean, default: false },
    label: { type: String, default: '' },
  },
  emits: ['click'],
  template: `
    <button
      type="button"
      :data-loading="isLoading"
      @click="$emit('click')"
    >
      {{ label }}
    </button>
  `,
};

const ValidBasicsStub = {
  props: {
    modelValue: { type: Object, required: true },
  },
  setup(props) {
    props.modelValue.name = 'modelo_valido';
    props.modelValue.body.text = 'Mensagem de teste';
  },
  template: '<div />',
};

const findButton = (wrapper, label) =>
  wrapper.findAll('button').find(button => button.text() === label);

describe('TemplateWorkspace', () => {
  it('can be unmounted immediately after a successful submission', async () => {
    metaTemplatesAPI.createTemplate.mockResolvedValue({
      data: { template: { id: 'template-1' } },
    });

    let wrapper;
    wrapper = mount(TemplateWorkspace, {
      props: {
        inboxId: 1,
        onSaved: () => wrapper.unmount(),
      },
      global: {
        stubs: {
          Button: ButtonStub,
          Spinner: true,
          Teleport: true,
          TemplateBasicsStep: ValidBasicsStub,
          TemplateContentStep: true,
          TemplateReviewStep: true,
          WhatsAppTemplatePreview: true,
        },
      },
    });

    await findButton(wrapper, 'CONTINUE').trigger('click');
    await findButton(wrapper, 'CONTINUE').trigger('click');
    await findButton(wrapper, 'CREATE').trigger('click');
    await flushPromises();

    expect(metaTemplatesAPI.createTemplate).toHaveBeenCalledOnce();
    expect(wrapper.exists()).toBe(false);
  });
});
