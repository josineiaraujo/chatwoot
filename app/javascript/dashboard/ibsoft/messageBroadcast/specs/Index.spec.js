import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import MessageBroadcastIndex from '../views/Index.vue';
import erpAPI from 'dashboard/ibsoft/erp/api';
import messageBroadcastAPI from '../api';

const alertMock = vi.fn();
const dispatchMock = vi.fn();
const dialogOpenMock = vi.fn();
const dialogCloseMock = vi.fn();
const groupEditorOpenMock = vi.fn();
const groupEditorCloseMock = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: { value: 'pt_BR' },
    t: (key, values = {}) =>
      Object.keys(values).reduce(
        (message, valueKey) =>
          message.replace(`{${valueKey}}`, values[valueKey]),
        key
      ),
  }),
}));

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch: dispatchMock,
    getters: {
      'inboxes/getInboxes': [
        {
          id: 1,
          name: 'WhatsApp',
          channel_type: 'Channel::Whatsapp',
          provider: 'whatsapp_cloud',
        },
        {
          id: 2,
          name: 'WhatsApp API não Cloud',
          channel_type: 'Channel::Whatsapp',
          provider: 'whatsapp_twilio',
        },
      ],
    },
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => alertMock(message),
}));

vi.mock('dashboard/ibsoft/erp/api', () => ({
  default: {
    getConnections: vi.fn(),
  },
}));

vi.mock('../api', () => ({
  default: {
    getCapabilities: vi.fn(),
    getGroups: vi.fn(),
    getGroup: vi.fn(),
    createGroup: vi.fn(),
    updateGroup: vi.fn(),
    getBroadcasts: vi.fn(),
    getBroadcast: vi.fn(),
    sendBroadcast: vi.fn(),
    deleteBroadcast: vi.fn(),
    deleteBroadcasts: vi.fn(),
    getTemplates: vi.fn(),
    getStates: vi.fn(),
    getCities: vi.fn(),
    getPlans: vi.fn(),
    getPops: vi.fn(),
    getTransmitters: vi.fn(),
    previewRecipients: vi.fn(),
    createBroadcast: vi.fn(),
  },
}));

const customer = {
  external_id: '4797',
  name: 'Cliente IXC',
  city_name: 'Salvador',
  state: 'BA',
  active: true,
  phone_selection: {
    primary_phone: '+5571999999999',
    fallback_phone: '+5571888888888',
    deliverable: true,
  },
};

const metaTemplate = {
  id: 'template-1',
  name: 'aviso_manutencao',
  language: 'pt_BR',
  status: 'APPROVED',
  category: 'UTILITY',
  components: [
    {
      type: 'BODY',
      text: 'Olá {{1}}, seu plano {{2}} terá manutenção.',
    },
  ],
  variables: [
    { key: '1', label: '{{1}}', component_type: 'BODY' },
    { key: '2', label: '{{2}}', component_type: 'BODY' },
  ],
};

const mediaHeaderTemplate = {
  id: 'template-media',
  name: 'boleto_com_documento',
  language: 'pt_BR',
  status: 'APPROVED',
  category: 'UTILITY',
  components: [
    { type: 'HEADER', format: 'DOCUMENT' },
    { type: 'BODY', text: 'Segue seu documento.' },
  ],
  variables: [
    {
      key: 'header_media_url',
      parameter_key: 'media_url',
      label: 'header_media_url',
      component_type: 'HEADER',
      parameter_type: 'media',
      media_type: 'document',
    },
  ],
};

const buttonTemplate = {
  id: 'template-buttons',
  name: 'aviso_com_acoes',
  language: 'pt_BR',
  status: 'APPROVED',
  category: 'UTILITY',
  components: [
    { type: 'BODY', text: 'Acompanhe sua solicitação.' },
    {
      type: 'BUTTONS',
      buttons: [
        { type: 'QUICK_REPLY', text: 'Falar com atendimento' },
        {
          type: 'URL',
          text: 'Acompanhar pedido',
          url: 'https://example.com/pedidos/{{tracking_code}}',
        },
        { type: 'COPY_CODE', text: 'Copiar código' },
      ],
    },
  ],
  variables: [
    {
      key: 'buttons:1:tracking_code',
      parameter_key: 'tracking_code',
      label: '{{tracking_code}}',
      component_type: 'BUTTONS',
      parameter_type: 'text',
      button_type: 'url',
      button_index: 1,
      button_text: 'Acompanhar pedido',
    },
    {
      key: 'buttons:2:copy_code',
      parameter_key: 'copy_code',
      label: '{{copy_code}}',
      component_type: 'BUTTONS',
      parameter_type: 'text',
      button_type: 'copy_code',
      button_index: 2,
      button_text: 'Copiar código',
    },
  ],
};

const mountComponent = () =>
  shallowMount(MessageBroadcastIndex, {
    global: {
      stubs: {
        Button: {
          props: ['label', 'disabled'],
          emits: ['click'],
          template:
            '<button type="button" :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
        },
        Spinner: true,
        Dialog: {
          props: ['title', 'description'],
          emits: ['close'],
          setup(_, { expose }) {
            expose({ open: dialogOpenMock, close: dialogCloseMock });
          },
          template:
            '<div data-testid="broadcast-detail-dialog"><slot /><slot name="footer" /></div>',
        },
        BroadcastWorkspace: {
          props: ['title', 'closeLabel', 'steps', 'activeStep'],
          emits: ['close', 'select-step'],
          template:
            '<div data-testid="message-broadcast-workspace"><slot /></div>',
        },
        RecipientSelectionDialog: {
          props: [
            'purpose',
            'selectionCount',
            'currentPageCount',
            'totalCount',
          ],
          emits: [
            'close',
            'confirm',
            'select-page',
            'select-all',
            'clear-selection',
          ],
          setup(_, { expose }) {
            expose({ open: dialogOpenMock, close: dialogCloseMock });
          },
          template:
            '<div data-testid="recipient-selection-dialog"><slot name="filters" /><slot name="results" /></div>',
        },
        GroupEditorDialog: {
          props: ['groupName', 'members', 'isLoading', 'isSaving'],
          emits: [
            'add',
            'close',
            'remove',
            'save',
            'update',
            'update:groupName',
          ],
          setup(_, { expose }) {
            expose({
              open: groupEditorOpenMock,
              close: groupEditorCloseMock,
            });
          },
          template: '<div data-testid="group-editor-dialog" />',
        },
        IbsoftSelect: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><slot /></select>',
        },
        RouterLink: {
          props: ['to'],
          template: '<a><slot /></a>',
        },
      },
      mocks: {
        $route: {
          params: {
            accountId: 1,
          },
        },
      },
    },
  });

describe('MessageBroadcastIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    dispatchMock.mockResolvedValue();
    erpAPI.getConnections.mockResolvedValue({
      data: {
        connections: [
          {
            id: 1,
            name: 'IXC produção',
            provider: 'ixc',
            active: true,
          },
        ],
      },
    });
    messageBroadcastAPI.getGroups.mockResolvedValue({
      data: {
        groups: [
          {
            id: 7,
            name: 'Clientes ativos',
            members_count: 1,
          },
        ],
      },
    });
    messageBroadcastAPI.getCapabilities.mockResolvedValue({
      data: {
        provider: 'ixc',
        capabilities: {
          search_modes: ['direct', 'contracts', 'concentrators'],
          location_filters: { city: 'lookup' },
          contract_filters: { internet_status: true },
          concentrator_filters: {
            manual_concentrator_ids: true,
            pops: true,
            transmitters: true,
            transmission_interfaces: true,
            ftth_boxes: true,
            transmitter_ports: true,
            transmitter_kind: 'transmitter',
          },
        },
      },
    });
    messageBroadcastAPI.getGroup.mockResolvedValue({
      data: {
        id: 7,
        name: 'Clientes ativos',
        members: [
          {
            external_customer_id: '4797',
            customer_name: 'Cliente IXC',
            primary_phone: '+5571999999999',
            fallback_phone: '',
            city: 'Salvador',
            state: 'BA',
            active: true,
          },
        ],
      },
    });
    messageBroadcastAPI.getBroadcasts.mockResolvedValue({
      data: {
        broadcasts: [
          {
            id: 10,
            template_name: 'aviso_manutencao',
            template_language: 'pt_BR',
            status: 'draft',
            deletable: true,
            dispatch_mode: 'bulk',
            conversation_mode: 'direct',
            recipients_count: 1,
            created_by: { id: 1, name: 'Administrador' },
            created_at: '2026-07-08T00:00:00Z',
          },
        ],
        meta: {
          page: 1,
          per_page: 30,
          total: 31,
          total_pages: 2,
        },
      },
    });
    messageBroadcastAPI.getBroadcast.mockResolvedValue({
      data: {
        id: 10,
        template_name: 'aviso_manutencao',
        template_language: 'pt_BR',
        status: 'draft',
        dispatch_mode: 'bulk',
        recipients_count: 1,
        conversation_mode: 'close_after_send',
        created_by: { id: 1, name: 'Administrador' },
        created_at: '2026-07-08T00:00:00Z',
        recipients: [
          {
            id: 1,
            customer_name: 'Cliente IXC',
            primary_phone: '+5571999999999',
            status: 'pending',
          },
        ],
      },
    });
    messageBroadcastAPI.sendBroadcast.mockResolvedValue({
      data: {
        id: 10,
        template_name: 'aviso_manutencao',
        template_language: 'pt_BR',
        status: 'queued',
        dispatch_mode: 'bulk',
        recipients_count: 1,
        conversation_mode: 'close_after_send',
        created_by: { id: 1, name: 'Administrador' },
        created_at: '2026-07-08T00:00:00Z',
        recipients: [
          {
            id: 1,
            customer_name: 'Cliente IXC',
            primary_phone: '+5571999999999',
            status: 'queued',
          },
        ],
      },
    });
    messageBroadcastAPI.deleteBroadcast.mockResolvedValue({ data: null });
    messageBroadcastAPI.deleteBroadcasts.mockResolvedValue({
      data: { deleted_ids: [10, 11] },
    });
    messageBroadcastAPI.getTemplates.mockResolvedValue({
      data: { templates: [metaTemplate] },
    });
    messageBroadcastAPI.getStates.mockResolvedValue({
      data: { states: [{ id: '5', abbreviation: 'BA', name: 'Bahia' }] },
    });
    messageBroadcastAPI.getCities.mockResolvedValue({ data: { cities: [] } });
    messageBroadcastAPI.getPlans.mockResolvedValue({ data: { plans: [] } });
    messageBroadcastAPI.getPops.mockResolvedValue({
      data: { pops: [] },
    });
    messageBroadcastAPI.getTransmitters.mockResolvedValue({
      data: { transmitters: [] },
    });
    messageBroadcastAPI.previewRecipients.mockResolvedValue({
      data: { customers: [customer] },
    });
    messageBroadcastAPI.createGroup.mockResolvedValue({ data: { id: 9 } });
    messageBroadcastAPI.updateGroup.mockResolvedValue({
      data: {
        id: 7,
        name: 'Clientes prioritários',
        members: [],
      },
    });
    messageBroadcastAPI.createBroadcast.mockResolvedValue({
      data: { id: 10, recipients: [] },
    });
  });

  it('keeps history full width and opens a dedicated builder workspace', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    const content = wrapper.get(
      '[data-testid="message-broadcast-page-content"]'
    );

    expect(content.classes()).toEqual(
      expect.arrayContaining(['mx-auto', 'w-full', 'max-w-none', 'px-4'])
    );

    wrapper.vm.startNewBroadcast();
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="message-broadcast-workspace"]').exists()
    ).toBe(true);
    expect(content.classes()).toContain('max-w-none');
  });

  it('does not load the ERP state catalog while only viewing history', async () => {
    erpAPI.getConnections.mockResolvedValue({
      data: {
        connections: [
          {
            id: 2,
            name: 'SGP produção',
            provider: 'sgp',
            active: true,
          },
        ],
      },
    });

    mountComponent();
    await flushPromises();

    expect(messageBroadcastAPI.getCapabilities).toHaveBeenCalledTimes(1);
    expect(messageBroadcastAPI.getStates).not.toHaveBeenCalled();
    expect(alertMock).not.toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'
    );
  });

  it('loads ERP states once when recipient selection is opened', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(messageBroadcastAPI.getStates).not.toHaveBeenCalled();

    wrapper.vm.openRecipientSelection('recipients');
    await flushPromises();
    wrapper.vm.openRecipientSelection('recipients');
    await flushPromises();

    expect(messageBroadcastAPI.getStates).toHaveBeenCalledTimes(1);
    expect(messageBroadcastAPI.getStates).toHaveBeenCalledWith({
      query: '',
      limit: 100,
    });
  });

  it('starts by choosing the sending scope and exposes only Cloud API channels', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.builderStep).toBe('setup');
    expect(
      wrapper.find('[data-testid="message-broadcast-workspace"]').exists()
    ).toBe(true);
    expect(wrapper.vm.dispatchMode).toBe('');
    expect(wrapper.vm.inboxOptions).toEqual([
      expect.objectContaining({ id: 1, provider: 'whatsapp_cloud' }),
    ]);
    expect(wrapper.vm.draftForm.inboxId).toBe(1);
    expect(wrapper.vm.canContinueSetup).toBeFalsy();

    const dispatchCards = wrapper
      .get('[data-testid="message-broadcast-setup-step"]')
      .findAll('button')
      .slice(0, 2);
    dispatchCards.forEach(card => {
      expect(card.classes()).not.toContain('min-h-24');
      expect(card.classes()).not.toContain('min-h-32');
    });

    wrapper.vm.selectDispatchMode('single');
    await flushPromises();

    expect(wrapper.vm.canContinueSetup).toBeTruthy();
    expect(wrapper.vm.sourceMode).toBe('search');
    expect(wrapper.vm.draftForm.conversationMode).toBe('direct');
  });

  it('keeps the visual template preview on the right and the summary below', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('single');
    wrapper.vm.selectedCustomers = [customer];
    await wrapper.vm.goToContent();
    await wrapper.vm.$nextTick();

    const step = wrapper.get('[data-testid="message-broadcast-content-step"]');
    const layout = wrapper.get(
      '[data-testid="message-broadcast-content-layout"]'
    );
    const summary = wrapper.get(
      '[data-testid="message-broadcast-content-summary"]'
    );

    expect(layout.classes()).toContain('lg:grid-cols-[minmax(0,1fr)_24rem]');
    expect(layout.find('template-preview-stub').exists()).toBe(true);
    expect(
      layout.find('[data-testid="message-broadcast-content-summary"]').exists()
    ).toBe(false);
    expect(summary.element.parentElement).toBe(step.element);
    expect(layout.element.nextElementSibling).toBe(summary.element);
  });

  it('protects an unfinished broadcast before closing the workspace', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.requestCloseBuilder();

    expect(dialogOpenMock).toHaveBeenCalledOnce();
    expect(wrapper.vm.currentView).toBe('builder');

    wrapper.vm.discardBuilder();
    await flushPromises();

    expect(dialogCloseMock).toHaveBeenCalledOnce();
    expect(wrapper.vm.currentView).toBe('history');
  });

  it('does not treat the only compatible channel as an unfinished change', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.requestCloseBuilder();
    await flushPromises();

    expect(dialogOpenMock).not.toHaveBeenCalled();
    expect(wrapper.vm.currentView).toBe('history');
  });

  it('allows navigation only through builder steps already reached', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    expect(wrapper.vm.stepItems[1].disabled).toBe(true);

    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.draftForm.inboxId = 1;
    wrapper.vm.goToRecipients();

    expect(wrapper.vm.builderStep).toBe('recipients');
    expect(wrapper.vm.stepItems[1].disabled).toBe(false);
    expect(wrapper.vm.stepItems[2].disabled).toBe(true);

    wrapper.vm.selectBuilderStep('setup');
    expect(wrapper.vm.builderStep).toBe('setup');

    wrapper.vm.selectBuilderStep('content');
    expect(wrapper.vm.builderStep).toBe('setup');
  });

  it('allows lookup fields to shrink inside responsive grid columns', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.draftForm.inboxId = 1;
    wrapper.vm.goToRecipients();
    wrapper.vm.chooseSource('search');
    await flushPromises();

    const lookupFields = wrapper.findAll('lookup-single-select-stub');

    expect(lookupFields).toHaveLength(2);
    lookupFields.forEach(field => {
      expect(field.element.parentElement.classList).toContain('min-w-0');
      expect(field.element.parentElement.classList).toContain('w-full');
    });
  });

  it('uses a full-width vertical recipient flow with the recipient table last', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.draftForm.inboxId = 1;
    wrapper.vm.goToRecipients();
    wrapper.vm.chooseSource('search');
    await flushPromises();

    const step = wrapper.get(
      '[data-testid="message-broadcast-recipient-step"]'
    );
    expect(step.classes()).toEqual(
      expect.arrayContaining(['flex', 'flex-col', 'min-w-0'])
    );
    expect(step.classes()).not.toContain('xl:grid-cols-[minmax(0,1fr)_360px]');
    expect(step.find('search-mode-menu-stub').exists()).toBe(true);
    expect(step.find('recipient-table-stub').exists()).toBe(true);
  });

  it('loads the active ERP connection and fixed groups', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(erpAPI.getConnections).toHaveBeenCalled();
    expect(messageBroadcastAPI.getGroups).toHaveBeenCalled();
    expect(messageBroadcastAPI.getBroadcasts).toHaveBeenCalled();
    expect(wrapper.text()).toContain('IXC produção');
    expect(wrapper.text()).toContain('aviso_manutencao');
  });

  it('adapts recipient filters to SGP capabilities without changing the shared flow', async () => {
    erpAPI.getConnections.mockResolvedValueOnce({
      data: {
        connections: [
          {
            id: 2,
            name: 'SGP produção',
            provider: 'sgp',
            active: true,
          },
        ],
      },
    });
    messageBroadcastAPI.getCapabilities.mockResolvedValueOnce({
      data: {
        provider: 'sgp',
        capabilities: {
          search_modes: ['direct', 'contracts', 'concentrators'],
          location_filters: { city: 'text' },
          contract_filters: { internet_status: false },
          concentrator_filters: {
            manual_concentrator_ids: false,
            pops: true,
            transmitters: true,
            transmission_interfaces: false,
            ftth_boxes: false,
            transmitter_ports: true,
            transmitter_kind: 'nas',
          },
        },
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.vm.activeConnection.provider).toBe('sgp');
    expect(wrapper.vm.modeOptions.map(mode => mode.id)).toEqual([
      'direct',
      'contracts',
      'concentrators',
    ]);
    expect(wrapper.vm.contractFilterCapabilities.internet_status).toBe(false);
    expect(wrapper.vm.usesCityLookup).toBe(false);
    expect(wrapper.vm.concentratorFilterCapabilities).toEqual(
      expect.objectContaining({
        manual_concentrator_ids: false,
        transmission_interfaces: false,
        ftth_boxes: false,
        transmitter_kind: 'nas',
      })
    );
    expect(wrapper.vm.transmitterLookupText).toEqual({
      label: 'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.NAS',
      placeholder: 'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.NAS_PLACEHOLDER',
      search: 'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.NAS_SEARCH',
    });

    messageBroadcastAPI.getCities.mockClear();
    wrapper.vm.directFilters.stateId = 'BA';
    await wrapper.vm.$nextTick();
    wrapper.vm.directFilters.cityName = 'Salvador';
    await wrapper.vm.fetchCities();
    expect(messageBroadcastAPI.getCities).not.toHaveBeenCalled();

    messageBroadcastAPI.previewRecipients.mockClear();
    await wrapper.vm.searchCustomers();
    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith(
      expect.objectContaining({
        filters: expect.objectContaining({
          state_id: 'BA',
          city_name: 'Salvador',
        }),
      })
    );
  });

  it('renders a paginated history table and loads the selected page', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(messageBroadcastAPI.getBroadcasts).toHaveBeenCalledWith({
      page: 1,
      per_page: 30,
    });
    expect(wrapper.find('table').exists()).toBe(true);
    expect(wrapper.text()).toContain('Administrador');
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.BROADCAST'
    );

    messageBroadcastAPI.getBroadcasts.mockResolvedValueOnce({
      data: {
        broadcasts: [
          {
            id: 9,
            template_name: 'segunda_pagina',
            template_language: 'pt_BR',
            status: 'completed',
            deletable: true,
            dispatch_mode: 'single',
            conversation_mode: 'direct',
            recipients_count: 1,
            created_by: { id: 2, name: 'Agente da segunda página' },
            created_at: '2026-07-07T00:00:00Z',
          },
        ],
        meta: {
          page: 2,
          per_page: 30,
          total: 31,
          total_pages: 2,
        },
      },
    });

    await wrapper.vm.changeHistoryPage(2);
    await flushPromises();

    expect(messageBroadcastAPI.getBroadcasts).toHaveBeenLastCalledWith({
      page: 2,
      per_page: 30,
    });
    expect(wrapper.vm.historyMeta.page).toBe(2);
    expect(wrapper.text()).toContain('segunda_pagina');
  });

  it('keeps pagination controls visible and changes the history page size', async () => {
    messageBroadcastAPI.getBroadcasts.mockResolvedValueOnce({
      data: {
        broadcasts: [
          {
            id: 10,
            template_name: 'aviso_manutencao',
            status: 'completed',
            deletable: true,
            dispatch_mode: 'bulk',
            conversation_mode: 'direct',
            recipients_count: 1,
            created_by: { id: 1, name: 'Administrador' },
            created_at: '2026-07-08T00:00:00Z',
          },
        ],
        meta: { page: 1, per_page: 30, total: 1, total_pages: 1 },
      },
    });
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.find('history-pagination-footer-stub').exists()).toBe(true);
    expect(
      wrapper.find('[data-testid="history-selection-toolbar"]').exists()
    ).toBe(false);

    messageBroadcastAPI.getBroadcasts.mockResolvedValueOnce({
      data: {
        broadcasts: [],
        meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
      },
    });
    await wrapper.vm.changeHistoryPerPage(10);

    expect(messageBroadcastAPI.getBroadcasts).toHaveBeenLastCalledWith({
      page: 1,
      per_page: 10,
    });
    expect(wrapper.vm.historyPerPage).toBe(10);
  });

  it('selects only deletable history items and deletes them in bulk', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.broadcasts = [
      { id: 10, template_name: 'concluido', deletable: true },
      { id: 11, template_name: 'falhou', deletable: true },
      { id: 12, template_name: 'executando', deletable: false },
    ];
    wrapper.vm.historyMeta = {
      page: 1,
      per_page: 30,
      total: 3,
      total_pages: 1,
    };
    await wrapper.vm.$nextTick();

    wrapper.vm.toggleHistoryPage(true);
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.selectedHistoryBroadcastIds).toEqual([10, 11]);
    expect(wrapper.vm.isHistoryPageSelected).toBe(true);
    expect(
      wrapper.find('[data-testid="history-selection-toolbar"]').exists()
    ).toBe(true);

    wrapper.vm.requestSelectedBroadcastDeletion();
    expect(dialogOpenMock).toHaveBeenCalled();

    await wrapper.vm.confirmHistoryDeletion();
    await flushPromises();

    expect(messageBroadcastAPI.deleteBroadcasts).toHaveBeenCalledWith([10, 11]);
    expect(wrapper.vm.selectedHistoryBroadcastIds).toEqual([]);
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DELETE_MANY_SUCCESS'
    );
  });

  it('previews recipients without sending messages', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.searchCustomers();

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith({
      mode: 'direct',
      page: 1,
      limit: 10,
      filters: {
        name: '',
        state_id: '',
        city_id: '',
        active: undefined,
        street: '',
        zip_code: '',
        neighborhood: '',
      },
    });
    expect(wrapper.vm.customers).toEqual([
      expect.objectContaining({ external_id: '4797', name: 'Cliente IXC' }),
    ]);
  });

  it('changes the result page size while preserving the cached search filters', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.searchCustomers();
    wrapper.vm.directFilters.name = 'filtro ainda não aplicado';
    messageBroadcastAPI.previewRecipients.mockClear();

    await wrapper.vm.changeResultPerPage(50);

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith({
      mode: 'direct',
      page: 1,
      limit: 50,
      filters: {
        name: '',
        state_id: '',
        city_id: '',
        active: undefined,
        street: '',
        zip_code: '',
        neighborhood: '',
      },
    });
    expect(wrapper.vm.resultPage).toBe(1);
    expect(wrapper.vm.resultPerPage).toBe(50);
  });

  it('searches the complete cached customer result without changing ERP filters', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.searchCustomers();
    messageBroadcastAPI.previewRecipients.mockClear();
    wrapper.vm.foundCustomersQuery = 'cliente 4797';

    await wrapper.vm.searchCustomers(1, wrapper.vm.activeSearch);

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith({
      mode: 'direct',
      page: 1,
      limit: 10,
      query: 'cliente 4797',
      filters: {
        name: '',
        state_id: '',
        city_id: '',
        active: undefined,
        street: '',
        zip_code: '',
        neighborhood: '',
      },
    });
  });

  it('polls while the normalized recipient snapshot is being built', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients
      .mockResolvedValueOnce({
        data: { status: 'building', retry_after: 0, search_token: 'search-1' },
      })
      .mockResolvedValueOnce({
        data: {
          status: 'ready',
          customers: [customer],
          total: 1,
          total_pages: 1,
          per_page: 10,
          cache_hit: true,
        },
      });

    await wrapper.vm.searchCustomers(1, null, { refresh: true });

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledTimes(2);
    expect(messageBroadcastAPI.previewRecipients).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({ refresh: true })
    );
    expect(messageBroadcastAPI.previewRecipients).toHaveBeenNthCalledWith(
      2,
      expect.not.objectContaining({ refresh: true })
    );
    expect(wrapper.vm.customers).toEqual([
      expect.objectContaining({ external_id: '4797' }),
    ]);
    expect(wrapper.vm.resultMeta.cache_hit).toBe(true);
  });

  it('adds every cached result in bounded 500-recipient pages', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients.mockImplementation(
      ({ page, limit }) => {
        if (limit === 10) {
          return Promise.resolve({
            data: {
              customers: [customer],
              total: 1001,
              total_pages: 41,
              per_page: 10,
              search_token: 'cached-search',
            },
          });
        }

        return Promise.resolve({
          data: {
            customers: [
              {
                ...customer,
                external_id: String(5000 + page),
                name: `Cliente página ${page}`,
              },
            ],
          },
        });
      }
    );

    await wrapper.vm.searchCustomers(1);
    await wrapper.vm.addAllResultsToRecipients();

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledTimes(4);
    expect(messageBroadcastAPI.previewRecipients).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({ page: 1, limit: 500 })
    );
    expect(messageBroadcastAPI.previewRecipients).toHaveBeenNthCalledWith(
      4,
      expect.objectContaining({ page: 3, limit: 500 })
    );
    expect(wrapper.vm.selectedCustomers.map(item => item.external_id)).toEqual([
      '5001',
      '5002',
      '5003',
    ]);
  });

  it('searches IXC states and cities for single selection filters', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.getStates.mockClear();
    messageBroadcastAPI.getStates.mockResolvedValue({
      data: { states: [{ id: '5', abbreviation: 'BA', name: 'Bahia' }] },
    });

    wrapper.vm.stateQuery = 'Bah';
    await wrapper.vm.fetchStates();

    expect(messageBroadcastAPI.getStates).toHaveBeenCalledWith({
      query: 'Bah',
      limit: 100,
    });

    messageBroadcastAPI.getCities.mockClear();
    messageBroadcastAPI.getCities.mockResolvedValue({
      data: { cities: [{ id: '2193', name: 'Salvador' }] },
    });

    wrapper.vm.directFilters.stateId = '5';
    wrapper.vm.cityQuery = 'Sal';
    await wrapper.vm.fetchCities();

    expect(messageBroadcastAPI.getCities).toHaveBeenCalledWith({
      state_id: '5',
      query: 'Sal',
      limit: 100,
    });
    expect(wrapper.vm.lookupOptions.cities).toEqual([
      { id: '2193', name: 'Salvador' },
    ]);
  });

  it('searches contract cities without changing direct city lookup options', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.getCities.mockClear();
    messageBroadcastAPI.getCities.mockResolvedValue({
      data: { cities: [{ id: '1840', name: 'Andaraí' }] },
    });

    wrapper.vm.contractFilters.stateId = '10';
    wrapper.vm.contractCityQuery = 'And';
    await wrapper.vm.fetchContractCities();

    expect(messageBroadcastAPI.getCities).toHaveBeenCalledWith({
      state_id: '10',
      query: 'And',
      limit: 100,
    });
    expect(wrapper.vm.lookupOptions.contractCities).toEqual([
      { id: '1840', name: 'Andaraí' },
    ]);
    expect(wrapper.vm.lookupOptions.cities).toEqual([]);
  });

  it('sends customer state and city filters in contract preview search', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients.mockClear();
    wrapper.vm.searchMode = 'contracts';
    wrapper.vm.contractFilters.clientActive = 'true';
    wrapper.vm.contractFilters.stateId = '10';
    wrapper.vm.contractFilters.cityId = '1840';
    wrapper.vm.contractFilters.contractStatus = 'A';
    wrapper.vm.contractFilters.internetStatus = 'CM';
    wrapper.vm.contractFilters.selectedPlanIds = ['33'];
    await wrapper.vm.searchCustomers();

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith({
      mode: 'contracts',
      page: 1,
      limit: 10,
      filters: {
        contract_statuses: ['A'],
        internet_statuses: ['CM'],
        plan_ids: ['33'],
        client_active: 'true',
        state_id: '10',
        city_id: '1840',
      },
    });
  });

  it('loads IXC access plans as selectable options for contract search', async () => {
    messageBroadcastAPI.getPlans.mockResolvedValue({
      data: {
        plans: [{ id: '33', name: 'Fibra 600 Mega', active: true }],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.searchMode = 'contracts';
    await flushPromises();

    expect(messageBroadcastAPI.getPlans).toHaveBeenCalledWith({
      query: '',
      limit: 50,
    });
    expect(wrapper.vm.lookupOptions.plans).toEqual([
      expect.objectContaining({ id: '33', name: 'Fibra 600 Mega' }),
    ]);
  });

  it('loads IXC transmitters and sends advanced PPPoE filters', async () => {
    messageBroadcastAPI.getPops.mockResolvedValue({
      data: {
        pops: [{ id: '22', name: 'POP Centro' }],
      },
    });
    messageBroadcastAPI.getTransmitters.mockResolvedValue({
      data: {
        transmitters: [{ id: '15', name: 'OLT_DATACOM_ANDARAI' }],
      },
    });

    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.searchMode = 'concentrators';
    await flushPromises();

    expect(messageBroadcastAPI.getTransmitters).toHaveBeenCalledWith({
      query: '',
      limit: 50,
    });
    expect(messageBroadcastAPI.getPops).toHaveBeenCalledWith({
      query: '',
      limit: 50,
    });

    messageBroadcastAPI.previewRecipients.mockClear();
    wrapper.vm.concentratorFilters.clientActive = 'true';
    wrapper.vm.concentratorFilters.concentratorIds = '24, 25';
    wrapper.vm.concentratorFilters.selectedPopIds = ['22', '24'];
    wrapper.vm.concentratorFilters.selectedTransmitterIds = ['15'];
    wrapper.vm.concentratorFilters.transmissionInterfaceIds = '164,117';
    wrapper.vm.concentratorFilters.ftthBoxIds = '9';
    wrapper.vm.concentratorFilters.transmitterPortIds = '31, 32';
    await wrapper.vm.searchCustomers();

    expect(messageBroadcastAPI.previewRecipients).toHaveBeenCalledWith({
      mode: 'concentrators',
      page: 1,
      limit: 10,
      filters: {
        concentrator_ids: ['24', '25'],
        client_active: 'true',
        pop_ids: ['22', '24'],
        transmitter_ids: ['15'],
        transmission_interface_ids: ['164', '117'],
        ftth_box_ids: ['9'],
        transmitter_port_ids: ['31', '32'],
      },
    });
  });

  it('saves selected customers as a fixed group', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.searchCustomers();
    wrapper.vm.toggleCustomer(customer);
    wrapper.vm.groupName = 'VIP';
    await wrapper.vm.saveGroup();

    expect(messageBroadcastAPI.createGroup).toHaveBeenCalledWith({
      name: 'VIP',
      members: [
        {
          external_customer_id: '4797',
          customer_name: 'Cliente IXC',
          primary_phone: '+5571999999999',
          fallback_phone: '+5571888888888',
          city: 'Salvador',
          state: 'BA',
          active: true,
        },
      ],
    });
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_CREATED'
    );
  });

  it('creates a fixed group from every page through the cached search token', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients.mockResolvedValue({
      data: {
        customers: [customer],
        total: 125,
        page: 1,
        per_page: 10,
        search_token: 'cached-search',
      },
    });

    await wrapper.vm.searchCustomers();
    wrapper.vm.selectAllResults();
    wrapper.vm.groupName = 'Todos os clientes';
    await wrapper.vm.saveGroup();

    expect(messageBroadcastAPI.createGroup).toHaveBeenCalledWith({
      name: 'Todos os clientes',
      selection: {
        scope: 'all',
        search_token: 'cached-search',
        query: '',
      },
    });
  });

  it('keeps the selection dialog open when the cached search expired', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients.mockResolvedValue({
      data: {
        customers: [customer],
        total: 125,
        page: 1,
        per_page: 10,
        search_token: 'cached-search',
      },
    });
    messageBroadcastAPI.createGroup.mockRejectedValueOnce({
      response: { data: { error: 'recipient_selection_expired' } },
    });
    await wrapper.vm.searchCustomers();
    wrapper.vm.selectAllResults();
    wrapper.vm.groupName = 'Todos os clientes';

    expect(await wrapper.vm.saveGroup()).toBe(false);
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SELECTION_EXPIRED'
    );
    expect(wrapper.vm.groupName).toBe('Todos os clientes');
  });

  it('shows how many customers are selected on the page or in all results', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    messageBroadcastAPI.previewRecipients.mockResolvedValue({
      data: {
        customers: [customer],
        total: 125,
        page: 1,
        per_page: 10,
        search_token: 'cached-search',
      },
    });

    await wrapper.vm.searchCustomers();
    wrapper.vm.toggleCurrentPageSelection();
    expect(wrapper.vm.resultSelectionScope).toBe('page');
    expect(wrapper.vm.selectedResultCount).toBe(1);

    wrapper.vm.selectAllResults();
    expect(wrapper.vm.resultSelectionScope).toBe('all');
    expect(wrapper.vm.selectedResultCount).toBe(125);
  });

  it('keeps group members collapsed while selecting and loads them only when continuing', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.chooseSource('groups');
    wrapper.vm.setBuilderStep('recipients');
    wrapper.vm.toggleGroup(wrapper.vm.groups[0]);
    await flushPromises();

    expect(messageBroadcastAPI.getGroup).not.toHaveBeenCalled();
    expect(wrapper.vm.selectedCustomers).toEqual([]);
    expect(wrapper.vm.selectedGroupIds).toEqual(['7']);
    expect(
      wrapper.find('[data-testid="selected-groups-summary"]').exists()
    ).toBe(true);
    expect(wrapper.find('recipient-table-stub').exists()).toBe(false);

    await wrapper.vm.goToContent();

    expect(messageBroadcastAPI.getGroup).toHaveBeenCalledWith(7);
    expect(wrapper.vm.selectedCustomers).toEqual([
      expect.objectContaining({
        external_id: '4797',
        name: 'Cliente IXC',
      }),
    ]);
    expect(wrapper.vm.builderStep).toBe('content');

    wrapper.vm.setBuilderStep('recipients');
    wrapper.vm.toggleGroup(wrapper.vm.groups[0]);
    expect(wrapper.vm.selectedCustomers).toEqual([]);
  });

  it('edits a fixed group without selecting it for the broadcast', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.chooseSource('groups');
    wrapper.vm.setBuilderStep('recipients');
    await wrapper.vm.$nextTick();

    await wrapper.get('[data-testid="edit-group-7"]').trigger('click');
    await flushPromises();

    expect(groupEditorOpenMock).toHaveBeenCalledOnce();
    expect(messageBroadcastAPI.getGroup).toHaveBeenCalledWith(7);
    expect(wrapper.vm.selectedGroupIds).toEqual([]);
    expect(wrapper.vm.editingGroupName).toBe('Clientes ativos');
    expect(wrapper.vm.editingGroupMembers).toEqual([
      expect.objectContaining({
        external_id: '4797',
        name: 'Cliente IXC',
      }),
    ]);

    wrapper.vm.editingGroupName = 'Clientes prioritários';
    wrapper.vm.removeGroupEditorMember(wrapper.vm.editingGroupMembers[0]);
    await wrapper.vm.saveGroupEditor();

    expect(messageBroadcastAPI.updateGroup).toHaveBeenCalledWith(7, {
      name: 'Clientes prioritários',
      members: [],
    });
    expect(messageBroadcastAPI.getGroups).toHaveBeenCalledTimes(2);
    expect(groupEditorCloseMock).toHaveBeenCalledOnce();
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_UPDATED'
    );
  });

  it('creates a broadcast draft from selected customers', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.selectDispatchMode('bulk');
    await wrapper.vm.searchCustomers();
    wrapper.vm.toggleCustomer(customer);
    wrapper.vm.addSelectedResultsToRecipients();
    wrapper.vm.draftForm.inboxId = 1;
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-1';
    await flushPromises();
    wrapper.vm.variableRows[1].type = 'fixed';
    wrapper.vm.variableRows[1].value = 'Fibra\n600 Mega';
    await wrapper.vm.createBroadcastDraft();

    expect(messageBroadcastAPI.createBroadcast).toHaveBeenCalledWith({
      inbox_id: 1,
      dispatch_mode: 'bulk',
      source_type: 'selection',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'direct',
      template_variables: {
        1: { type: 'customer_field', field: 'name', component_type: 'BODY' },
        2: { type: 'fixed', value: 'Fibra 600 Mega', component_type: 'BODY' },
      },
      recipients: [
        {
          external_customer_id: '4797',
          customer_name: 'Cliente IXC',
          primary_phone: '+5571999999999',
          fallback_phone: '+5571888888888',
          template_variable_values: {
            1: 'Cliente IXC',
          },
        },
      ],
    });
  });

  it('creates and queues a broadcast directly from the sending step', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('bulk');
    wrapper.vm.chooseSource('search');
    await wrapper.vm.searchCustomers();
    wrapper.vm.toggleCustomer(customer);
    wrapper.vm.addSelectedResultsToRecipients();
    wrapper.vm.draftForm.inboxId = 1;
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-1';
    await flushPromises();
    wrapper.vm.variableRows[1].type = 'fixed';
    wrapper.vm.variableRows[1].value = 'Fibra 600 Mega';
    wrapper.vm.goToReview();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.START_BROADCAST'
    );
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SAVE_DRAFT'
    );

    await wrapper.vm.sendBroadcastNow();

    expect(messageBroadcastAPI.createBroadcast).toHaveBeenCalledWith({
      inbox_id: 1,
      dispatch_mode: 'bulk',
      source_type: 'selection',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'direct',
      template_variables: {
        1: { type: 'customer_field', field: 'name', component_type: 'BODY' },
        2: { type: 'fixed', value: 'Fibra 600 Mega', component_type: 'BODY' },
      },
      recipients: [
        {
          external_customer_id: '4797',
          customer_name: 'Cliente IXC',
          primary_phone: '+5571999999999',
          fallback_phone: '+5571888888888',
          template_variable_values: {
            1: 'Cliente IXC',
          },
        },
      ],
      send_now: true,
    });
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SEND_STARTED'
    );
  });

  it('keeps a single recipient exclusive and sends both phone candidates', async () => {
    const secondCustomer = {
      ...customer,
      external_id: '4798',
      name: 'Segundo cliente',
      phone_selection: {
        primary_phone: '+5571977777777',
        fallback_phone: '+5571966666666',
        deliverable: true,
      },
    };
    messageBroadcastAPI.previewRecipients.mockResolvedValue({
      data: { customers: [customer, secondCustomer] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
    wrapper.vm.selectDispatchMode('single');
    wrapper.vm.draftForm.inboxId = 1;
    wrapper.vm.goToRecipients();
    await wrapper.vm.searchCustomers();
    wrapper.vm.toggleCustomer(customer);
    wrapper.vm.toggleCustomer(secondCustomer);
    wrapper.vm.addSelectedResultsToRecipients();
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-1';
    await flushPromises();
    wrapper.vm.variableRows[1].type = 'fixed';
    wrapper.vm.variableRows[1].value = 'Fibra 600 Mega';

    expect(wrapper.vm.selectedCustomers).toEqual([
      expect.objectContaining(secondCustomer),
    ]);
    expect(wrapper.vm.canGoToContent).toBe(true);

    await wrapper.vm.sendBroadcastNow();

    expect(messageBroadcastAPI.createBroadcast).toHaveBeenCalledWith(
      expect.objectContaining({
        inbox_id: 1,
        dispatch_mode: 'single',
        source_type: 'selection',
        conversation_mode: 'direct',
        recipients: [
          expect.objectContaining({
            external_customer_id: '4798',
            primary_phone: '+5571977777777',
            fallback_phone: '+5571966666666',
          }),
        ],
        send_now: true,
      })
    );
  });

  it('enables conversation registration only when explicitly selected', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.vm.draftForm.conversationMode).toBe('direct');

    wrapper.vm.startNewBroadcast();
    wrapper.vm.builderStep = 'delivery';
    await wrapper.vm.$nextTick();
    const deliveryCards = wrapper
      .get('[data-testid="message-broadcast-delivery-step"]')
      .findAll('button')
      .slice(0, 2);
    deliveryCards.forEach(card => {
      expect(card.classes()).not.toContain('min-h-32');
    });

    wrapper.vm.selectDelivery('conversation');
    expect(wrapper.vm.draftForm.conversationMode).toBe('close_after_send');
    expect(wrapper.vm.usesConversation).toBe(true);

    wrapper.vm.draftForm.conversationMode = 'keep_open';
    expect(wrapper.vm.conversationModeLabel('keep_open')).toBe(
      'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.KEEP_OPEN'
    );

    wrapper.vm.selectDelivery('direct');
    expect(wrapper.vm.draftForm.conversationMode).toBe('direct');
    expect(wrapper.vm.usesConversation).toBe(false);
  });

  it('opens a draft and starts sending it', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.openBroadcast({ id: 10 });
    await flushPromises();

    expect(messageBroadcastAPI.getBroadcast).toHaveBeenCalledWith(10);
    expect(wrapper.vm.currentView).toBe('history');
    expect(dialogOpenMock).toHaveBeenCalledOnce();
    expect(wrapper.text()).toContain('Cliente IXC');
    expect(wrapper.text()).toContain('Administrador');

    await wrapper.vm.sendSelectedBroadcast();
    await flushPromises();

    expect(messageBroadcastAPI.sendBroadcast).toHaveBeenCalledWith(10);
    expect(wrapper.vm.selectedBroadcast.status).toBe('queued');
    expect(alertMock).toHaveBeenCalledWith(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SEND_STARTED'
    );
  });

  it('loads Meta templates and derives variables from the selected template', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.draftForm.inboxId = 1;
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-1';
    await flushPromises();

    expect(messageBroadcastAPI.getTemplates).toHaveBeenCalledWith({
      inbox_id: 1,
    });
    expect(wrapper.vm.selectedTemplate).toEqual(metaTemplate);
    expect(wrapper.vm.variableRows).toEqual([
      expect.objectContaining({
        key: '1',
        type: 'customer_field',
        field: 'name',
      }),
      expect.objectContaining({
        key: '2',
        type: 'customer_field',
        field: 'name',
      }),
    ]);
  });

  it('requires and serializes a public media URL for a template header', async () => {
    messageBroadcastAPI.getTemplates.mockResolvedValue({
      data: { templates: [mediaHeaderTemplate] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.draftForm.inboxId = 1;
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-media';
    await flushPromises();

    expect(wrapper.vm.variableRows).toEqual([
      expect.objectContaining({
        key: 'header_media_url',
        type: 'fixed',
        component_type: 'HEADER',
        parameter_key: 'media_url',
        parameter_type: 'media',
        media_type: 'document',
      }),
    ]);

    wrapper.vm.variableRows[0].value = 'arquivo-invalido';
    expect(wrapper.vm.canGoToDelivery).toBe(false);

    wrapper.vm.variableRows[0].value =
      'https://cdn.example.com/fatura-julho.pdf';
    expect(wrapper.vm.canGoToDelivery).toBe(true);
    expect(wrapper.vm.templateVariablesPayload()).toEqual({
      header_media_url: {
        type: 'fixed',
        value: 'https://cdn.example.com/fatura-julho.pdf',
        component_type: 'HEADER',
        parameter_key: 'media_url',
        parameter_type: 'media',
        media_type: 'document',
      },
    });
  });

  it('configures dynamic URL and copy-code buttons with their original indexes', async () => {
    messageBroadcastAPI.getTemplates.mockResolvedValue({
      data: { templates: [buttonTemplate] },
    });
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.draftForm.inboxId = 1;
    await wrapper.vm.fetchTemplates();
    wrapper.vm.draftForm.templateId = 'template-buttons';
    await flushPromises();

    expect(wrapper.vm.variableRows).toEqual([
      expect.objectContaining({
        key: 'buttons:1:tracking_code',
        type: 'customer_field',
        field: 'name',
        button_type: 'url',
        button_index: 1,
      }),
      expect.objectContaining({
        key: 'buttons:2:copy_code',
        type: 'fixed',
        field: '',
        button_type: 'copy_code',
        button_index: 2,
      }),
    ]);
    expect(wrapper.vm.canGoToDelivery).toBe(false);

    wrapper.vm.variableRows[0].type = 'fixed';
    wrapper.vm.variableRows[0].value = 'pedido-42';
    wrapper.vm.variableRows[1].value = 'CODIGO-COM-MAIS-DE-15';
    expect(wrapper.vm.canGoToDelivery).toBe(false);

    wrapper.vm.variableRows[1].value = 'PIX123';
    expect(wrapper.vm.canGoToDelivery).toBe(true);
    expect(wrapper.vm.templateVariablesPayload()).toEqual({
      'buttons:1:tracking_code': {
        type: 'fixed',
        value: 'pedido-42',
        component_type: 'BUTTONS',
        button_type: 'url',
        button_index: 1,
        parameter_key: 'tracking_code',
        parameter_type: 'text',
      },
      'buttons:2:copy_code': {
        type: 'fixed',
        value: 'PIX123',
        component_type: 'BUTTONS',
        button_type: 'copy_code',
        button_index: 2,
        parameter_key: 'copy_code',
        parameter_type: 'text',
      },
    });
  });
});
