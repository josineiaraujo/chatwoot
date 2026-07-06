import { flushPromises, shallowMount } from '@vue/test-utils';
import { h } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import AgentProvisioningPanel from '../components/AgentProvisioningPanel.vue';
import agentProvisioningAPI from '../api';

const alertMock = vi.fn();
const dispatchPointerEvent = (element, type, options) => {
  const event = new MouseEvent(type, { bubbles: true, ...options });
  Object.defineProperty(event, 'pointerId', { value: 1 });
  element.dispatchEvent(event);
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) =>
      Object.keys(params).reduce(
        (label, param) => label.replace(`{${param}}`, params[param]),
        key
      ),
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('../api', () => ({
  default: {
    getAgents: vi.fn(),
    createAgent: vi.fn(),
    updateAgent: vi.fn(),
    deleteAgent: vi.fn(),
    resetTemporaryPassword: vi.fn(),
    saveProfileAssignment: vi.fn(),
    deleteProfileAssignment: vi.fn(),
  },
}));

const agentPayload = customAttributes => ({
  id: 11,
  name: 'Agente Atual',
  email: 'atual@example.com',
  role: 'agent',
  availability: 'offline',
  availability_status: 'offline',
  auto_offline: true,
  confirmed: true,
  thumbnail: '',
  ...customAttributes,
});

const mountComponent = () =>
  shallowMount(AgentProvisioningPanel, {
    global: {
      stubs: {
        Button: {
          props: ['label', 'disabled'],
          template:
            '<button v-bind="$attrs" :disabled="disabled" ' +
            '@click="$emit(\'click\')">{{ label }}</button>',
        },
        IbsoftSelect: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select v-bind="$attrs" :value="modelValue" ' +
            '@change="$emit(\'update:modelValue\', $event.target.value)">' +
            '<slot /></select>',
        },
        ToggleSwitch: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<button v-bind="$attrs" type="button" ' +
            '@click="$emit(\'update:modelValue\', !modelValue)">' +
            '{{ modelValue }}</button>',
        },
        Dialog: {
          props: ['disableConfirmButton'],
          emits: ['confirm', 'close'],
          setup(_props, { slots, emit, expose }) {
            expose({ open: vi.fn(), close: vi.fn() });
            return () =>
              h('div', { class: 'dialog-stub' }, [
                slots.default?.(),
                h(
                  'button',
                  {
                    class: 'dialog-confirm',
                    disabled: _props.disableConfirmButton,
                    onClick: () => emit('confirm'),
                  },
                  'confirm'
                ),
              ]);
          },
        },
        Spinner: true,
        Avatar: {
          name: 'Avatar',
          props: ['src', 'name', 'status', 'size'],
          template: '<div data-testid="agent-avatar" />',
        },
      },
    },
  });

describe('AgentProvisioningPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    agentProvisioningAPI.updateAgent.mockResolvedValue({});
    agentProvisioningAPI.deleteAgent.mockResolvedValue({});
    agentProvisioningAPI.resetTemporaryPassword.mockResolvedValue({
      data: {
        agent: agentPayload(),
        temporary_password: 'NewTempPassword1!',
      },
    });
    agentProvisioningAPI.saveProfileAssignment.mockResolvedValue({});
    agentProvisioningAPI.deleteProfileAssignment.mockResolvedValue({});
  });

  it('renders agent avatars using the thumbnail from the API', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValueOnce({
      data: {
        agents: [
          agentPayload({
            thumbnail: 'https://example.com/avatar.png',
          }),
        ],
        profiles: [],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    const avatar = wrapper.findComponent({ name: 'Avatar' });
    expect(avatar.props('src')).toBe('https://example.com/avatar.png');
    expect(avatar.props('name')).toBe('Agente Atual');
    expect(avatar.props('status')).toBe('offline');
    expect(avatar.props('size')).toBe(36);
  });

  it('uses the effective availability as the selected status', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValueOnce({
      data: {
        agents: [
          agentPayload({
            availability: 'online',
            availability_status: 'offline',
          }),
        ],
        profiles: [],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="agent-availability-select"]').element.value
    ).toBe('offline');
  });

  it('creates an agent and displays the temporary password from the response', async () => {
    agentProvisioningAPI.getAgents
      .mockResolvedValueOnce({ data: { agents: [], profiles: [] } })
      .mockResolvedValueOnce({
        data: {
          agents: [
            {
              id: 10,
              name: 'Novo Agente',
              email: 'novo@example.com',
              role: 'agent',
              confirmed: true,
            },
          ],
          profiles: [],
        },
      });
    agentProvisioningAPI.createAgent.mockResolvedValue({
      data: {
        agent: {
          id: 10,
          name: 'Novo Agente',
          email: 'novo@example.com',
          role: 'agent',
          confirmed: true,
        },
        temporary_password: 'TempPassword1!',
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .find('[data-testid="agent-create-name"]')
      .setValue('Novo Agente');
    await wrapper
      .find('[data-testid="agent-create-email"]')
      .setValue('novo@example.com');
    await wrapper.findAll('.dialog-confirm')[0].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.createAgent).toHaveBeenCalledWith({
      name: 'Novo Agente',
      email: 'novo@example.com',
      role: 'agent',
      profile_id: null,
      auto_offline: true,
    });
    expect(
      wrapper.find('[data-testid="agent-create-temporary-password"]').element
        .value
    ).toBe('TempPassword1!');
  });

  it('sends the selected profile id when a named profile is selected', async () => {
    agentProvisioningAPI.getAgents
      .mockResolvedValueOnce({
        data: {
          agents: [],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      })
      .mockResolvedValueOnce({
        data: {
          agents: [
            {
              id: 11,
              name: 'Perfil Agente',
              email: 'perfil@example.com',
              role: 'agent',
              confirmed: true,
              profile: { id: 25, name: 'Supervisor' },
            },
          ],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      });
    agentProvisioningAPI.createAgent.mockResolvedValue({
      data: {
        agent: {
          id: 11,
          name: 'Perfil Agente',
          email: 'perfil@example.com',
          role: 'agent',
          confirmed: true,
          profile: { id: 25, name: 'Supervisor' },
        },
        temporary_password: 'TempPassword1!',
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .find('[data-testid="agent-create-name"]')
      .setValue('Perfil Agente');
    await wrapper
      .find('[data-testid="agent-create-email"]')
      .setValue('perfil@example.com');
    await wrapper
      .find('[data-testid="agent-create-profile"]')
      .setValue('profile:25');
    await wrapper.findAll('.dialog-confirm')[0].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.createAgent).toHaveBeenCalledWith({
      name: 'Perfil Agente',
      email: 'perfil@example.com',
      role: 'agent',
      profile_id: 25,
      auto_offline: true,
    });
  });

  it('allows disabling automatic offline while creating an agent', async () => {
    agentProvisioningAPI.getAgents
      .mockResolvedValueOnce({ data: { agents: [], profiles: [] } })
      .mockResolvedValueOnce({
        data: {
          agents: [
            agentPayload({
              name: 'Sem Automático',
              email: 'manual@example.com',
              auto_offline: false,
            }),
          ],
          profiles: [],
        },
      });
    agentProvisioningAPI.createAgent.mockResolvedValue({
      data: {
        agent: agentPayload({
          name: 'Sem Automático',
          email: 'manual@example.com',
          auto_offline: false,
        }),
        temporary_password: 'TempPassword1!',
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .find('[data-testid="agent-create-name"]')
      .setValue('Sem Automático');
    await wrapper
      .find('[data-testid="agent-create-email"]')
      .setValue('manual@example.com');
    await wrapper
      .find('[data-testid="agent-create-auto-offline"]')
      .trigger('click');
    await wrapper.findAll('.dialog-confirm')[0].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.createAgent).toHaveBeenCalledWith({
      name: 'Sem Automático',
      email: 'manual@example.com',
      role: 'agent',
      profile_id: null,
      auto_offline: false,
    });
  });

  it('updates an agent and moves them to the selected profile', async () => {
    agentProvisioningAPI.getAgents
      .mockResolvedValueOnce({
        data: {
          agents: [agentPayload()],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      })
      .mockResolvedValueOnce({
        data: {
          agents: [
            agentPayload({
              name: 'Agente Editado',
              profile: { id: 25, name: 'Supervisor' },
            }),
          ],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.find('[data-testid="agent-edit-button"]').trigger('click');
    await wrapper
      .find('[data-testid="agent-edit-name"]')
      .setValue('Agente Editado');
    await wrapper
      .find('[data-testid="agent-edit-email"]')
      .setValue('editado@example.com');
    await wrapper
      .find('[data-testid="agent-edit-profile"]')
      .setValue('profile:25');
    await wrapper.findAll('.dialog-confirm')[1].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.updateAgent).toHaveBeenCalledWith(11, {
      name: 'Agente Editado',
      email: 'editado@example.com',
      role: 'agent',
      availability: 'offline',
      auto_offline: true,
    });
    expect(agentProvisioningAPI.saveProfileAssignment).toHaveBeenCalledWith({
      userId: 11,
      roleId: 25,
    });
  });

  it('updates the agent availability from the list', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValue({
      data: {
        agents: [agentPayload({ auto_offline: false })],
        profiles: [],
      },
    });
    agentProvisioningAPI.updateAgent.mockResolvedValue({
      data: {
        agent: agentPayload({
          availability: 'online',
          availability_status: 'online',
        }),
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper
      .find('[data-testid="agent-availability-select"]')
      .setValue('online');
    await flushPromises();

    expect(agentProvisioningAPI.updateAgent).toHaveBeenCalledWith(11, {
      availability: 'online',
    });
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY_UPDATED'
    );
  });

  it('updates the automatic offline option while editing an agent', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValueOnce({
      data: {
        agents: [agentPayload()],
        profiles: [],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.find('[data-testid="agent-edit-button"]').trigger('click');
    await wrapper
      .find('[data-testid="agent-edit-auto-offline"]')
      .trigger('click');
    await wrapper.findAll('.dialog-confirm')[1].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.updateAgent).toHaveBeenCalledWith(11, {
      name: 'Agente Atual',
      email: 'atual@example.com',
      role: 'agent',
      availability: 'offline',
      auto_offline: false,
    });
  });

  it('generates a new temporary password while editing an agent', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValue({
      data: {
        agents: [agentPayload()],
        profiles: [],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.find('[data-testid="agent-edit-button"]').trigger('click');
    await wrapper
      .find('[data-testid="agent-reset-password-button"]')
      .trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.resetTemporaryPassword).toHaveBeenCalledWith(
      11
    );
    expect(
      wrapper.find('[data-testid="agent-edit-temporary-password"]').element
        .value
    ).toBe('NewTempPassword1!');
  });

  it('allows moving the selected avatar inside the crop area', async () => {
    agentProvisioningAPI.getAgents.mockResolvedValue({
      data: {
        agents: [],
        profiles: [],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    wrapper.findAllComponents({ name: 'Avatar' })[0].vm.$emit('upload', {
      file: new File(['avatar'], 'avatar.png', { type: 'image/png' }),
      url: 'blob:agent-avatar',
    });
    await flushPromises();

    await wrapper.find('input[type="range"]').setValue('2');
    const cropArea = wrapper.find(
      '[data-testid="agent-avatar-crop-area"]'
    ).element;
    dispatchPointerEvent(cropArea, 'pointerdown', { clientX: 20, clientY: 20 });
    dispatchPointerEvent(cropArea, 'pointermove', { clientX: 52, clientY: 44 });
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="agent-avatar-crop-image"]')
        .attributes('style')
    ).toContain('transform: translate(32px, 24px)');
  });

  it('uses the moved avatar position when generating the cropped file', async () => {
    const drawImage = vi.fn();
    const originalImage = window.Image;
    const originalCreateObjectURL = URL.createObjectURL;
    const originalCreateElement = document.createElement.bind(document);
    const createElement = vi
      .spyOn(document, 'createElement')
      .mockImplementation(tagName => {
        if (tagName !== 'canvas') return originalCreateElement(tagName);

        return {
          getContext: () => ({
            beginPath: vi.fn(),
            arc: vi.fn(),
            clip: vi.fn(),
            drawImage,
          }),
          toBlob: callback =>
            callback(new Blob(['avatar'], { type: 'image/png' })),
        };
      });

    window.Image = class {
      naturalWidth = 800;

      naturalHeight = 400;

      set src(_value) {
        this.onload?.();
      }
    };
    URL.createObjectURL = vi.fn(() => 'blob:cropped-agent-avatar');
    agentProvisioningAPI.getAgents.mockResolvedValue({
      data: {
        agents: [],
        profiles: [],
      },
    });

    try {
      const wrapper = mountComponent();
      await flushPromises();

      wrapper.findAllComponents({ name: 'Avatar' })[0].vm.$emit('upload', {
        file: new File(['avatar'], 'avatar.png', { type: 'image/png' }),
        url: 'blob:agent-avatar',
      });
      await flushPromises();

      await wrapper.find('input[type="range"]').setValue('2');
      const cropArea = wrapper.find(
        '[data-testid="agent-avatar-crop-area"]'
      ).element;
      dispatchPointerEvent(cropArea, 'pointerdown', {
        clientX: 20,
        clientY: 20,
      });
      dispatchPointerEvent(cropArea, 'pointermove', {
        clientX: 52,
        clientY: 44,
      });
      Object.defineProperty(cropArea, 'getBoundingClientRect', {
        value: () => ({
          left: 0,
          top: 0,
          width: 256,
          height: 256,
        }),
      });
      Object.defineProperty(
        wrapper.find('[data-testid="agent-avatar-crop-image"]').element,
        'getBoundingClientRect',
        {
          value: () => ({
            left: -352,
            top: -104,
            width: 1024,
            height: 512,
          }),
        }
      );
      await wrapper.findAll('.dialog-confirm')[2].trigger('click');
      await flushPromises();

      expect(drawImage).toHaveBeenCalledWith(
        expect.any(Object),
        -704,
        -208,
        2048,
        1024
      );
    } finally {
      createElement.mockRestore();
      window.Image = originalImage;
      URL.createObjectURL = originalCreateObjectURL;
    }
  });

  it('removes the profile assignment before deleting an agent', async () => {
    agentProvisioningAPI.getAgents
      .mockResolvedValueOnce({
        data: {
          agents: [
            agentPayload({
              profile_assignment_id: 30,
              profile: { id: 25, name: 'Supervisor' },
            }),
          ],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      })
      .mockResolvedValueOnce({
        data: {
          agents: [],
          profiles: [{ id: 25, name: 'Supervisor' }],
        },
      });

    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.find('[data-testid="agent-delete-button"]').trigger('click');
    await wrapper.findAll('.dialog-confirm')[3].trigger('click');
    await flushPromises();

    expect(agentProvisioningAPI.deleteProfileAssignment).toHaveBeenCalledWith(
      30
    );
    expect(agentProvisioningAPI.deleteAgent).toHaveBeenCalledWith(11);
  });
});
