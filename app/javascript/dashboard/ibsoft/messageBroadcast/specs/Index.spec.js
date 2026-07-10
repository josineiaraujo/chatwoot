import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import MessageBroadcastIndex from '../views/Index.vue';
import erpAPI from 'dashboard/ibsoft/erp/api';
import messageBroadcastAPI from '../api';

const alertMock = vi.fn();
const dispatchMock = vi.fn();

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
    getGroups: vi.fn(),
    createGroup: vi.fn(),
    getBroadcasts: vi.fn(),
    getBroadcast: vi.fn(),
    sendBroadcast: vi.fn(),
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
        ],
      },
    });
    messageBroadcastAPI.getBroadcasts.mockResolvedValue({
      data: {
        broadcasts: [
          {
            id: 10,
            template_name: 'aviso_manutencao',
            status: 'draft',
            recipients_count: 1,
            created_at: '2026-07-08T00:00:00Z',
          },
        ],
      },
    });
    messageBroadcastAPI.getBroadcast.mockResolvedValue({
      data: {
        id: 10,
        template_name: 'aviso_manutencao',
        template_language: 'pt_BR',
        status: 'draft',
        recipients_count: 1,
        conversation_mode: 'close_after_send',
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
        recipients_count: 1,
        conversation_mode: 'close_after_send',
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
    messageBroadcastAPI.createBroadcast.mockResolvedValue({
      data: { id: 10, recipients: [] },
    });
  });

  it('uses the native constrained responsive page layout', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    const content = wrapper.get(
      '[data-testid="message-broadcast-page-content"]'
    );

    expect(content.classes()).toEqual(
      expect.arrayContaining(['mx-auto', 'w-full', 'max-w-5xl', 'px-6'])
    );
    expect(content.classes()).not.toContain('max-w-none');
  });

  it('allows lookup fields to shrink inside responsive grid columns', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    wrapper.vm.startNewBroadcast();
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

  it('creates a broadcast draft from selected customers', async () => {
    const wrapper = mountComponent();
    await flushPromises();

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
      source_type: 'selection',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'close_after_send',
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
      'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEND_NOW'
    );
    expect(wrapper.text()).toContain(
      'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SAVE_DRAFT'
    );

    await wrapper.vm.sendBroadcastNow();

    expect(messageBroadcastAPI.createBroadcast).toHaveBeenCalledWith({
      inbox_id: 1,
      source_type: 'selection',
      template_name: 'aviso_manutencao',
      template_language: 'pt_BR',
      conversation_mode: 'close_after_send',
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

  it('opens a draft and starts sending it', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.vm.openBroadcast({ id: 10 });
    await flushPromises();

    expect(messageBroadcastAPI.getBroadcast).toHaveBeenCalledWith(10);
    expect(wrapper.vm.currentView).toBe('detail');
    expect(wrapper.text()).toContain('Cliente IXC');

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
});
