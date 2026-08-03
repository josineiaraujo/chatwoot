import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import BroadcastWorkspace from '../components/BroadcastWorkspace.vue';

const steps = [
  {
    id: 'setup',
    icon: 'i-lucide-settings-2',
    label: 'Início',
    disabled: false,
  },
  {
    id: 'recipients',
    icon: 'i-lucide-users-round',
    label: 'Destinatários',
    disabled: false,
  },
  {
    id: 'content',
    icon: 'i-lucide-message-square-text',
    label: 'Mensagem',
    disabled: true,
  },
];

const mountComponent = () =>
  shallowMount(BroadcastWorkspace, {
    props: {
      title: 'Novo disparo',
      closeLabel: 'Fechar criação do disparo',
      steps,
      activeStep: 'recipients',
    },
    slots: {
      default: '<section data-testid="workspace-content">Conteúdo</section>',
    },
    global: {
      stubs: {
        TeleportWithDirection: {
          template: '<div dir="ltr"><slot /></div>',
        },
        Button: {
          emits: ['click'],
          template: '<button type="button" @click="$emit(\'click\')" />',
        },
      },
    },
  });

describe('BroadcastWorkspace', () => {
  it('renders the workflow and emits navigation for enabled steps', async () => {
    const wrapper = mountComponent();
    const navigationButtons = wrapper.findAll('nav button');

    expect(wrapper.text()).toContain('Novo disparo');
    expect(wrapper.find('[data-testid="workspace-content"]').exists()).toBe(
      true
    );
    expect(
      wrapper.get('[data-testid="message-broadcast-workspace"]').element
        .parentElement.dir
    ).toBe('ltr');
    expect(navigationButtons).toHaveLength(3);
    expect(navigationButtons[2].attributes('disabled')).toBeDefined();

    await navigationButtons[0].trigger('click');

    expect(wrapper.emitted('select-step')).toEqual([['setup']]);
  });

  it('emits close from the workspace header', async () => {
    const wrapper = mountComponent();

    await wrapper.get('header button').trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
