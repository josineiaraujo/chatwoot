import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import InstanceCard from '../components/InstanceCard.vue';

const mountComponent = () =>
  shallowMount(InstanceCard, {
    props: {
      endpoint: {
        id: 7,
        name: 'ERP principal',
        inbox_name: 'WhatsApp Cloud',
        active: true,
        rate_limit_per_second: 10,
        deliveries_count: 4,
      },
      typeDefinition: {
        label: 'SGP Genérico',
        icon: 'i-lucide-braces',
      },
    },
    global: {
      mocks: {
        $t: key => key,
      },
      stubs: {
        Button: true,
        InstanceTypeMark: true,
      },
    },
  });

describe('InstanceCard', () => {
  it('shows the WhatsApp channel in its own row', () => {
    const wrapper = mountComponent();

    expect(wrapper.find('.i-ri-whatsapp-fill').exists()).toBe(true);
    expect(wrapper.text()).toContain('WhatsApp Cloud');
    expect(wrapper.text()).toContain(
      'IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CHANNEL'
    );
  });
});
