import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import InstanceTypeMark from '../components/InstanceTypeMark.vue';

describe('InstanceTypeMark', () => {
  it('renders the theme-specific logos when the type has a visual identity', () => {
    const wrapper = shallowMount(InstanceTypeMark, {
      props: {
        typeDefinition: {
          logo: {
            light: '/sgp/light.png',
            dark: '/sgp/dark.png',
          },
        },
      },
    });

    const images = wrapper.findAll('img');

    expect(images).toHaveLength(2);
    expect(images[0].attributes('src')).toBe('/sgp/light.png');
    expect(images[0].classes()).toContain('dark:hidden');
    expect(images[1].attributes('src')).toBe('/sgp/dark.png');
    expect(images[1].classes()).toContain('dark:block');
  });

  it('uses the configured icon when the type has no logo', () => {
    const wrapper = shallowMount(InstanceTypeMark, {
      props: {
        typeDefinition: {
          icon: 'i-lucide-plug',
        },
      },
    });

    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.find('i').classes()).toContain('i-lucide-plug');
  });
});
