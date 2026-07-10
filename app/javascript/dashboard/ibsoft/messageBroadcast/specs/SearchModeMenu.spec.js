import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import SearchModeMenu from '../components/SearchModeMenu.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const options = [
  { id: 'direct', title: 'Busca direta', icon: 'i-lucide-search' },
  { id: 'contracts', title: 'Contratos', icon: 'i-lucide-file' },
  { id: 'concentrators', title: 'Concentradores', icon: 'i-lucide-router' },
];

describe('SearchModeMenu', () => {
  it('renders a centered segmented menu and emits the selected mode', async () => {
    const wrapper = mount(SearchModeMenu, {
      props: { modelValue: 'direct', options },
    });

    expect(wrapper.get('nav').classes()).toEqual(
      expect.arrayContaining(['mx-auto', 'max-w-2xl', 'sm:grid-cols-3'])
    );
    const activeMode = wrapper.get('button[aria-pressed="true"]');
    expect(activeMode.text()).toBe('Busca direta');
    expect(activeMode.classes()).toContain('bg-n-alpha-3');
    expect(activeMode.classes()).not.toContain('bg-n-background');

    await wrapper.findAll('button')[1].trigger('click');

    expect(wrapper.emitted('update:modelValue')).toEqual([['contracts']]);
  });
});
