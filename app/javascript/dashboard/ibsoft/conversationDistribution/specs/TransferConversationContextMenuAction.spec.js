import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import fluentIcons from 'shared/components/FluentIcon/dashboard-icons.json';
import TransferConversationContextMenuAction from '../components/TransferConversationContextMenuAction.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountComponent = (disabled = false) =>
  shallowMount(TransferConversationContextMenuAction, {
    props: { disabled },
    global: {
      stubs: {
        MenuItemWithSubmenu: {
          props: ['option', 'subMenuAvailable'],
          template:
            '<div class="transfer-menu" :data-icon="option.icon" :data-enabled="subMenuAvailable"><slot /></div>',
        },
        MenuItem: {
          props: ['option'],
          emits: ['click'],
          template:
            '<button :class="option.key" type="button" @click="$emit(\'click\', $event)">{{ option.label }}</button>',
        },
      },
    },
  });

describe('TransferConversationContextMenuAction', () => {
  it('offers agent and department queue transfer actions', async () => {
    const wrapper = mountComponent();

    expect(
      fluentIcons[
        `${wrapper.find('.transfer-menu').attributes('data-icon')}-outline`
      ]
    ).toBeTruthy();

    await wrapper.find('.transfer-to-agent').trigger('click');
    await wrapper.find('.transfer-to-team-queue').trigger('click');

    expect(wrapper.emitted('agent')).toEqual([[]]);
    expect(wrapper.emitted('queue')).toEqual([[]]);
  });

  it('does not make the submenu available for closed conversations', () => {
    expect(
      mountComponent(true).find('.transfer-menu').attributes('data-enabled')
    ).toBe('false');
  });
});
