import { shallowMount } from '@vue/test-utils';

import SenderNameExamplePreview from '../SenderNameExamplePreview.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('shared/composables/useBranding', () => ({
  useBranding: () => ({
    replaceInstallationName: text => text.replace(/Chatwoot/g, 'ChatHub'),
  }),
}));

const mountComponent = props =>
  shallowMount(SenderNameExamplePreview, {
    props,
    global: {
      stubs: {
        Avatar: true,
        RadioCard: {
          props: ['label', 'description'],
          emits: ['select'],
          template:
            '<section><h3>{{ label }}</h3><p>{{ description }}</p><slot /></section>',
        },
      },
    },
  });

describe('SenderNameExamplePreview', () => {
  it('uses installation branding for the default business name preview', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('ChatHub');
    expect(wrapper.text()).not.toContain('Chatwoot');
  });

  it('keeps explicit business name above the branded fallback', () => {
    const wrapper = mountComponent({ businessName: 'Ibsoft' });

    expect(wrapper.text()).toContain('Ibsoft');
    expect(wrapper.text()).not.toContain('ChatHub');
  });
});
