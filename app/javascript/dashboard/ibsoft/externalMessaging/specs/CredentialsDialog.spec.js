import { mount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import CredentialsDialog from '../components/CredentialsDialog.vue';

const dialogOpenMock = vi.fn();
const dialogCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

const mountComponent = () =>
  mount(CredentialsDialog, {
    global: {
      stubs: {
        Dialog: {
          name: 'Dialog',
          props: {
            overflowYAuto: {
              type: Boolean,
              default: false,
            },
          },
          setup(props, { slots, expose }) {
            expose({
              open: dialogOpenMock,
              close: dialogCloseMock,
            });
            return () =>
              h(
                'section',
                { 'data-overflow-y-auto': String(props.overflowYAuto) },
                slots.default?.()
              );
          },
        },
      },
    },
  });

describe('CredentialsDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('opens active token metadata without rotating the credential', async () => {
    const wrapper = mountComponent();
    const endpoint = {
      id: 7,
      authentication: {
        type: 'token',
        secret_hint: 'ibext_active...',
      },
    };

    await wrapper.vm.open(endpoint);

    expect(dialogOpenMock).toHaveBeenCalledOnce();
    expect(wrapper.text()).toContain('ibext_active...');
    expect(wrapper.emitted('rotate')).toBeUndefined();
    expect(wrapper.find('[data-overflow-y-auto="true"]').exists()).toBe(true);
  });

  it('shows IXC safe metadata and rotates only after an explicit command', async () => {
    const wrapper = mountComponent();
    const endpoint = {
      id: 8,
      authentication: {
        type: 'username_password',
        username: 'ixc_8',
        secret_hint: 'ibext_ixc...',
      },
    };

    await wrapper.vm.open(endpoint);
    wrapper.vm.requestRotation();

    expect(wrapper.text()).toContain('ixc_8');
    expect(wrapper.text()).toContain('ibext_ixc...');
    expect(wrapper.emitted('rotate')).toEqual([[endpoint]]);
  });
});
