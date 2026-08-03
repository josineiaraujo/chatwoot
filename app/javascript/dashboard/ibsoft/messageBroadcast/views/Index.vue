<script setup>
/* eslint-disable no-use-before-define -- handlers are grouped by screen workflow */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import erpAPI from 'dashboard/ibsoft/erp/api';
import LookupMultiSelect from '../components/LookupMultiSelect.vue';
import LookupSingleSelect from '../components/LookupSingleSelect.vue';
import HistoryPaginationFooter from '../components/HistoryPaginationFooter.vue';
import GroupEditorDialog from '../components/GroupEditorDialog.vue';
import PageSizeSelect from '../components/PageSizeSelect.vue';
import RecipientTable from '../components/RecipientTable.vue';
import RecipientSelectionDialog from '../components/RecipientSelectionDialog.vue';
import SearchModeMenu from '../components/SearchModeMenu.vue';
import TemplatePreview from '../components/TemplatePreview.vue';
import BroadcastWorkspace from '../components/BroadcastWorkspace.vue';
import messageBroadcastAPI from '../api';

const { t, locale } = useI18n();
const store = useStore();

const LOOKUP_DEBOUNCE_MS = 350;
const DEFAULT_PER_PAGE = 10;
const HISTORY_PER_PAGE = 30;
const HISTORY_PAGE_SIZES = [10, 25, 30, 50, 100];
const COPY_CODE_MAX_LENGTH = 15;
const defaultProviderCapabilities = () => ({
  search_modes: ['direct', 'contracts', 'concentrators'],
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
});
const BUILDER_STEP_IDS = [
  'setup',
  'recipients',
  'content',
  'delivery',
  'review',
];
const inputClass =
  '!mb-0 box-border min-h-10 w-full rounded-lg border-0 bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-transparent transition-colors hover:outline-n-weak focus:outline-n-brand';
const singleLineValue = value =>
  String(value || '')
    .replace(/[\r\n]+/g, ' ')
    .trim();
const isMediaHeaderVariable = row =>
  row?.component_type === 'HEADER' && row?.parameter_type === 'media';
const isButtonVariable = row => row?.component_type === 'BUTTONS';
const isCopyCodeButtonVariable = row =>
  isButtonVariable(row) && row?.button_type === 'copy_code';
const isDynamicUrlButtonVariable = row =>
  isButtonVariable(row) && row?.button_type === 'url';
const isValidPublicUrl = value => {
  try {
    return ['http:', 'https:'].includes(
      new URL(singleLineValue(value)).protocol
    );
  } catch {
    return false;
  }
};

const isBooting = ref(false);
const isSearching = ref(false);
const isSavingGroup = ref(false);
const isCreatingBroadcast = ref(false);
const isSendingBroadcastNow = ref(false);
const isLoadingBroadcastDetail = ref(false);
const isSendingBroadcast = ref(false);
const isLoadingHistory = ref(false);
const isLoadingStates = ref(false);
const isLoadingCities = ref(false);
const isLoadingPlans = ref(false);
const isLoadingPops = ref(false);
const isLoadingTransmitters = ref(false);
const isLoadingTemplates = ref(false);
const isAddingAllResults = ref(false);
const isAddingGroups = ref(false);
const isLoadingGroupEditor = ref(false);
const isSavingGroupEditor = ref(false);
const isDeletingBroadcasts = ref(false);

const currentView = ref('history');
const builderStep = ref('setup');
const maxVisitedBuilderStepIndex = ref(0);
const dispatchMode = ref('');
const sourceMode = ref('');
const searchMode = ref('direct');
const recipientSelectionPurpose = ref('recipients');
const resultSelectionScope = ref('none');
const templateQuery = ref('');
const resultPage = ref(1);
const resultPerPage = ref(DEFAULT_PER_PAGE);
const foundCustomersQuery = ref('');
const resultMeta = ref({
  has_more: false,
  source_total: 0,
  source_returned: 0,
  total: 0,
  total_pages: 0,
  per_page: DEFAULT_PER_PAGE,
  search_token: '',
  cache_hit: false,
});
const activeSearch = ref(null);

const activeConnection = ref(null);
const providerCapabilities = ref(defaultProviderCapabilities());
const broadcasts = ref([]);
const historyMeta = ref({
  page: 1,
  per_page: HISTORY_PER_PAGE,
  total: 0,
  total_pages: 1,
});
const historyPerPage = ref(HISTORY_PER_PAGE);
const selectedHistoryBroadcastIds = ref([]);
const pendingHistoryDeletionIds = ref([]);
const broadcastDetailDialogRef = ref(null);
const deleteBroadcastDialogRef = ref(null);
const discardBuilderDialogRef = ref(null);
const recipientSelectionDialogRef = ref(null);
const groupEditorDialogRef = ref(null);
const selectedBroadcast = ref(null);
const groups = ref([]);
const customers = ref([]);
const templateOptions = ref([]);
const selectedResultIds = ref([]);
const selectedGroupIds = ref([]);
const selectedCustomers = ref([]);
const groupName = ref('');
const editingGroup = ref(null);
const editingGroupName = ref('');
const editingGroupMembers = ref([]);

const directFilters = ref({
  name: '',
  stateId: '',
  cityId: '',
  active: '',
  street: '',
  zipCode: '',
  neighborhood: '',
});
const contractFilters = ref({
  clientActive: '',
  stateId: '',
  cityId: '',
  contractStatus: '',
  internetStatus: '',
  planQuery: '',
  selectedPlanIds: [],
});
const concentratorFilters = ref({
  clientActive: '',
  concentratorIds: '',
  popQuery: '',
  selectedPopIds: [],
  transmitterQuery: '',
  selectedTransmitterIds: [],
  transmissionInterfaceIds: '',
  ftthBoxIds: '',
  transmitterPortIds: '',
});
const lookupOptions = ref({
  states: [],
  cities: [],
  contractCities: [],
  plans: [],
  pops: [],
  transmitters: [],
});
const stateQuery = ref('');
const cityQuery = ref('');
const contractCityQuery = ref('');
const draftForm = ref({
  inboxId: '',
  templateId: '',
  conversationMode: 'direct',
});
const variableRows = ref([]);

let cityLookupTimer;
let contractCityLookupTimer;
let stateLookupTimer;
let planLookupTimer;
let popLookupTimer;
let transmitterLookupTimer;
let foundCustomersSearchTimer;
let recipientSearchRequestId = 0;
let groupEditorRequestId = 0;

const hasActiveConnection = computed(() => Boolean(activeConnection.value));
const hasRecipients = computed(() => selectedCustomers.value.length > 0);
const selectedPhoneCount = computed(
  () =>
    selectedCustomers.value.filter(
      customer => customer.phone_selection?.deliverable
    ).length
);

const stepItems = computed(() =>
  [
    {
      id: 'setup',
      icon: 'i-lucide-settings-2',
      label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.SETUP'),
    },
    {
      id: 'recipients',
      icon: 'i-lucide-users-round',
      label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.RECIPIENTS'),
    },
    {
      id: 'content',
      icon: 'i-lucide-message-square-text',
      label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.CONTENT'),
    },
    {
      id: 'delivery',
      icon: 'i-lucide-messages-square',
      label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.DELIVERY'),
    },
    {
      id: 'review',
      icon: 'i-lucide-check-check',
      label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.REVIEW'),
    },
  ].map((step, index) => ({
    ...step,
    disabled: index > maxVisitedBuilderStepIndex.value,
  }))
);

const dispatchOptions = computed(() => [
  {
    id: 'single',
    icon: 'i-lucide-user-round',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.SINGLE_TITLE'),
    description: t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.SINGLE_DESCRIPTION'
    ),
  },
  {
    id: 'bulk',
    icon: 'i-lucide-users-round',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.BULK_TITLE'),
    description: t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.BULK_DESCRIPTION'),
  },
]);

const sourceOptions = computed(() => [
  {
    id: 'search',
    icon: 'i-lucide-search',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.SOURCE.SEARCH_TITLE'),
    description: t('IBSOFT_THEME.MESSAGE_BROADCAST.SOURCE.SEARCH_DESCRIPTION'),
  },
  {
    id: 'groups',
    icon: 'i-lucide-users-round',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.SOURCE.GROUPS_TITLE'),
    description: t('IBSOFT_THEME.MESSAGE_BROADCAST.SOURCE.GROUPS_DESCRIPTION'),
  },
]);

const modeOptions = computed(() => {
  const supportedModes = providerCapabilities.value.search_modes || [];
  return [
    {
      id: 'direct',
      icon: 'i-lucide-search',
      title: t('IBSOFT_THEME.MESSAGE_BROADCAST.MODES.DIRECT.TITLE'),
    },
    {
      id: 'contracts',
      icon: 'i-lucide-file-check-2',
      title: t('IBSOFT_THEME.MESSAGE_BROADCAST.MODES.CONTRACTS.TITLE'),
    },
    {
      id: 'concentrators',
      icon: 'i-lucide-router',
      title: t('IBSOFT_THEME.MESSAGE_BROADCAST.MODES.CONCENTRATORS.TITLE'),
    },
  ].filter(option => supportedModes.includes(option.id));
});

const contractFilterCapabilities = computed(
  () => providerCapabilities.value.contract_filters || {}
);
const concentratorFilterCapabilities = computed(
  () => providerCapabilities.value.concentrator_filters || {}
);
const transmitterLookupText = computed(() => {
  const isNas = concentratorFilterCapabilities.value.transmitter_kind === 'nas';
  return {
    label: isNas
      ? t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.NAS')
      : t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMITTER'),
    placeholder: isNas
      ? t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.NAS_PLACEHOLDER')
      : t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.TRANSMITTERS_PLACEHOLDER'),
    search: isNas
      ? t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.NAS_SEARCH')
      : t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.TRANSMITTERS_SEARCH'),
  };
});

const customerActiveOptions = computed(() => [
  { value: '', label: t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_STATUS') },
  { value: 'true', label: t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ACTIVE') },
  {
    value: 'false',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.INACTIVE'),
  },
]);

const contractStatusOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_CONTRACT'),
  },
  {
    value: 'A',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTRACT_STATUS.ACTIVE'),
  },
  {
    value: 'I',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTRACT_STATUS.INACTIVE'),
  },
  {
    value: 'P',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTRACT_STATUS.PRE_CONTRACT'),
  },
  {
    value: 'D',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTRACT_STATUS.CANCELLED'),
  },
]);

const internetStatusOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_INTERNET'),
  },
  {
    value: 'A',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.INTERNET_STATUS.ACTIVE'),
  },
  {
    value: 'D',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.INTERNET_STATUS.DISABLED'),
  },
  {
    value: 'CM',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.INTERNET_STATUS.MANUAL_BLOCK'),
  },
  {
    value: 'CA',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.INTERNET_STATUS.AUTO_BLOCK'),
  },
  {
    value: 'AA',
    label: t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.INTERNET_STATUS.WAITING_ACTIVATION'
    ),
  },
]);

const conversationModeOptions = computed(() => [
  {
    value: 'close_after_send',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CLOSE_AFTER_SEND'),
  },
  {
    value: 'keep_open',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.KEEP_OPEN'),
  },
]);

const deliveryOptions = computed(() => [
  {
    id: 'direct',
    icon: 'i-lucide-send',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.DIRECT_TITLE'),
    description: t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.DIRECT_DESCRIPTION'
    ),
  },
  {
    id: 'conversation',
    icon: 'i-lucide-messages-square',
    title: t('IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.CONVERSATION_TITLE'),
    description: t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.CONVERSATION_DESCRIPTION'
    ),
  },
]);

const variableTypeOptions = computed(() => [
  {
    value: 'customer_field',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.CUSTOMER_FIELD'),
  },
  {
    value: 'fixed',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.FIXED_VALUE'),
  },
]);

const customerFieldOptions = computed(() => [
  {
    value: 'name',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.NAME'),
  },
  {
    value: 'document',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.DOCUMENT'),
  },
  {
    value: 'address',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.ADDRESS'),
  },
  {
    value: 'city_name',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.CITY'),
  },
  {
    value: 'state',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.STATE'),
  },
  {
    value: 'primary_phone',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.PRIMARY_PHONE'),
  },
  {
    value: 'fallback_phone',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.CUSTOMER_FIELDS.FALLBACK_PHONE'),
  },
]);

const inboxOptions = computed(() => {
  const inboxes = store.getters['inboxes/getInboxes'] || [];
  return inboxes.filter(
    inbox =>
      inbox.channel_type === 'Channel::Whatsapp' &&
      inbox.provider === 'whatsapp_cloud'
  );
});
const defaultInboxId = computed(() =>
  inboxOptions.value.length === 1 ? inboxOptions.value[0].id : ''
);
const selectedInbox = computed(() =>
  inboxOptions.value.find(
    inbox => String(inbox.id) === String(draftForm.value.inboxId)
  )
);
const stateOptions = computed(() =>
  lookupOptions.value.states.map(state => ({
    value: state.id,
    label: `${state.abbreviation} - ${state.name}`,
  }))
);
const cityOptions = computed(() =>
  lookupOptions.value.cities.map(city => ({
    value: city.id,
    label: city.name,
  }))
);
const contractCityOptions = computed(() =>
  lookupOptions.value.contractCities.map(city => ({
    value: city.id,
    label: city.name,
  }))
);

const resultSelectedSet = computed(() => new Set(selectedResultIds.value));
const selectedResultCustomers = computed(() =>
  customers.value.filter(customer =>
    resultSelectedSet.value.has(customer.external_id)
  )
);
const selectedGroups = computed(() =>
  groups.value.filter(group =>
    selectedGroupIds.value.includes(String(group.id))
  )
);
const isGroupSource = computed(
  () => dispatchMode.value === 'bulk' && sourceMode.value === 'groups'
);
const selectedResultCount = computed(() =>
  resultSelectionScope.value === 'all'
    ? resultMeta.value.total
    : selectedResultIds.value.length
);
const selectedTemplate = computed(() =>
  templateOptions.value.find(
    template => String(template.id) === String(draftForm.value.templateId)
  )
);
const filteredTemplates = computed(() => {
  const query = templateQuery.value.trim().toLocaleLowerCase();
  if (!query) return templateOptions.value;

  return templateOptions.value.filter(template =>
    [
      template.name,
      template.language,
      template.category,
      ...(template.components || []).map(component => component.text),
    ]
      .filter(Boolean)
      .some(value => String(value).toLocaleLowerCase().includes(query))
  );
});
const selectedBroadcastRecipients = computed(
  () => selectedBroadcast.value?.recipients || []
);
const selectedBroadcastTitle = computed(() =>
  selectedBroadcast.value
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.TITLE', {
        id: selectedBroadcast.value.id,
      })
    : ''
);
const selectedBroadcastDescription = computed(() =>
  selectedBroadcast.value
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.TEMPLATE_META', {
        name: selectedBroadcast.value.template_name,
        language: selectedBroadcast.value.template_language,
      })
    : ''
);
const canSendSelectedBroadcast = computed(
  () => selectedBroadcast.value?.status === 'draft'
);
const selectedHistoryBroadcastIdSet = computed(
  () => new Set(selectedHistoryBroadcastIds.value)
);
const deletableHistoryBroadcasts = computed(() =>
  broadcasts.value.filter(broadcast => broadcast.deletable)
);
const selectedHistoryCount = computed(
  () => selectedHistoryBroadcastIds.value.length
);
const isHistoryPageSelected = computed(
  () =>
    deletableHistoryBroadcasts.value.length > 0 &&
    deletableHistoryBroadcasts.value.every(broadcast =>
      selectedHistoryBroadcastIdSet.value.has(broadcast.id)
    )
);
const pendingHistoryDeletionCount = computed(
  () => pendingHistoryDeletionIds.value.length
);
const historyDeletionTitle = computed(() =>
  pendingHistoryDeletionCount.value === 1
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.ONE_TITLE')
    : t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.MANY_TITLE', {
        count: pendingHistoryDeletionCount.value,
      })
);
const historyDeletionDescription = computed(() =>
  pendingHistoryDeletionCount.value === 1
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.ONE_DESCRIPTION')
    : t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.MANY_DESCRIPTION', {
        count: pendingHistoryDeletionCount.value,
      })
);

const hasSelectedResults = computed(() => selectedResultCount.value > 0);
const isCurrentPageSelected = computed(
  () =>
    customers.value.length > 0 &&
    (resultSelectionScope.value === 'all' ||
      customers.value.every(customer =>
        resultSelectedSet.value.has(customer.external_id)
      ))
);
const canContinueSetup = computed(
  () => dispatchMode.value && draftForm.value.inboxId
);
const canGoToContent = computed(() => {
  if (dispatchMode.value === 'single') {
    return selectedCustomers.value.length === 1;
  }

  return isGroupSource.value
    ? selectedGroupIds.value.length > 0
    : hasRecipients.value;
});
const areTemplateVariablesConfigured = computed(() =>
  variableRows.value.every(row => {
    if (isMediaHeaderVariable(row)) return isValidPublicUrl(row.value);
    if (isCopyCodeButtonVariable(row)) {
      const value = singleLineValue(row.value);
      return value.length > 0 && value.length <= COPY_CODE_MAX_LENGTH;
    }

    return row.type === 'fixed'
      ? singleLineValue(row.value).length > 0
      : row.field;
  })
);
const canGoToDelivery = computed(
  () => selectedTemplate.value && areTemplateVariablesConfigured.value
);
const canGoToReview = computed(
  () => canGoToContent.value && canGoToDelivery.value
);
const canCreateBroadcast = computed(
  () =>
    dispatchMode.value &&
    draftForm.value.inboxId &&
    selectedTemplate.value &&
    areTemplateVariablesConfigured.value &&
    hasRecipients.value
);
const canSendNewBroadcast = computed(
  () => canCreateBroadcast.value && selectedPhoneCount.value > 0
);
const hasBuilderChanges = computed(
  () =>
    builderStep.value !== 'setup' ||
    Boolean(dispatchMode.value) ||
    Boolean(sourceMode.value) ||
    (Boolean(draftForm.value.inboxId) &&
      String(draftForm.value.inboxId) !== String(defaultInboxId.value)) ||
    Boolean(draftForm.value.templateId) ||
    selectedCustomers.value.length > 0 ||
    selectedGroupIds.value.length > 0 ||
    Boolean(groupName.value.trim()) ||
    variableRows.value.some(row => Boolean(row.value))
);
const sendActionLabel = computed(() =>
  dispatchMode.value === 'single'
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEND_SINGLE')
    : t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.START_BROADCAST')
);
const isSubmittingBroadcast = computed(
  () => isCreatingBroadcast.value || isSendingBroadcastNow.value
);
const isConfirmingRecipientSelection = computed(
  () => isAddingAllResults.value || isSavingGroup.value
);
const usesConversation = computed(
  () => draftForm.value.conversationMode !== 'direct'
);
const dateTimeLocale = computed(() =>
  String(locale.value || 'pt-BR').replace('_', '-')
);

const boot = async () => {
  isBooting.value = true;
  try {
    await Promise.all([
      store.dispatch('inboxes/get'),
      fetchErpStatus(),
      fetchGroups(),
      fetchBroadcasts(),
    ]);
    if (activeConnection.value) {
      await Promise.all([fetchCapabilities(), fetchStates()]);
    }
  } finally {
    isBooting.value = false;
  }
};

async function fetchErpStatus() {
  const { data } = await erpAPI.getConnections();
  activeConnection.value =
    data.connections?.find(connection => connection.active) || null;
}

async function fetchCapabilities() {
  providerCapabilities.value = defaultProviderCapabilities();
  if (!activeConnection.value) return;

  try {
    const { data } = await messageBroadcastAPI.getCapabilities();
    providerCapabilities.value = {
      ...defaultProviderCapabilities(),
      ...(data.capabilities || {}),
      contract_filters: {
        ...defaultProviderCapabilities().contract_filters,
        ...(data.capabilities?.contract_filters || {}),
      },
      concentrator_filters: {
        ...defaultProviderCapabilities().concentrator_filters,
        ...(data.capabilities?.concentrator_filters || {}),
      },
    };
    if (!providerCapabilities.value.search_modes.includes(searchMode.value)) {
      searchMode.value = providerCapabilities.value.search_modes[0] || 'direct';
    }
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  }
}

async function fetchBroadcasts(page = historyMeta.value.page) {
  isLoadingHistory.value = true;
  try {
    const { data } = await messageBroadcastAPI.getBroadcasts({
      page,
      per_page: historyPerPage.value,
    });
    broadcasts.value = data.broadcasts || [];
    historyMeta.value = {
      page: data.meta?.page ?? page,
      per_page: data.meta?.per_page ?? historyPerPage.value,
      total: data.meta?.total ?? broadcasts.value.length,
      total_pages: data.meta?.total_pages ?? 1,
    };
    historyPerPage.value = historyMeta.value.per_page;
    selectedHistoryBroadcastIds.value =
      selectedHistoryBroadcastIds.value.filter(id =>
        broadcasts.value.some(
          broadcast => broadcast.id === id && broadcast.deletable
        )
      );
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.HISTORY_LOAD_ERROR'));
  } finally {
    isLoadingHistory.value = false;
  }
}

const fetchTemplates = async () => {
  templateOptions.value = [];
  draftForm.value.templateId = '';
  variableRows.value = [];

  if (!draftForm.value.inboxId) return;

  isLoadingTemplates.value = true;
  try {
    const { data } = await messageBroadcastAPI.getTemplates({
      inbox_id: draftForm.value.inboxId,
    });
    templateOptions.value = data.templates || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_LOAD_ERROR'));
  } finally {
    isLoadingTemplates.value = false;
  }
};

async function fetchGroups() {
  const { data } = await messageBroadcastAPI.getGroups();
  groups.value = data.groups || [];
}

async function fetchStates() {
  isLoadingStates.value = true;
  try {
    const { data } = await messageBroadcastAPI.getStates({
      query: stateQuery.value,
      limit: 100,
    });
    lookupOptions.value.states = data.states || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingStates.value = false;
  }
}

const fetchCities = async () => {
  if (!directFilters.value.stateId) {
    lookupOptions.value.cities = [];
    directFilters.value.cityId = '';
    return;
  }

  isLoadingCities.value = true;
  try {
    const { data } = await messageBroadcastAPI.getCities({
      state_id: directFilters.value.stateId,
      query: cityQuery.value,
      limit: 100,
    });
    lookupOptions.value.cities = data.cities || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingCities.value = false;
  }
};

const fetchContractCities = async () => {
  if (!contractFilters.value.stateId) {
    lookupOptions.value.contractCities = [];
    contractFilters.value.cityId = '';
    return;
  }

  isLoadingCities.value = true;
  try {
    const { data } = await messageBroadcastAPI.getCities({
      state_id: contractFilters.value.stateId,
      query: contractCityQuery.value,
      limit: 100,
    });
    lookupOptions.value.contractCities = data.cities || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingCities.value = false;
  }
};

const fetchPlans = async () => {
  isLoadingPlans.value = true;
  try {
    const { data } = await messageBroadcastAPI.getPlans({
      query: contractFilters.value.planQuery,
      limit: 50,
    });
    lookupOptions.value.plans = data.plans || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingPlans.value = false;
  }
};

const fetchPops = async () => {
  isLoadingPops.value = true;
  try {
    const { data } = await messageBroadcastAPI.getPops({
      query: concentratorFilters.value.popQuery,
      limit: 50,
    });
    lookupOptions.value.pops = data.pops || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingPops.value = false;
  }
};

const fetchTransmitters = async () => {
  isLoadingTransmitters.value = true;
  try {
    const { data } = await messageBroadcastAPI.getTransmitters({
      query: concentratorFilters.value.transmitterQuery,
      limit: 50,
    });
    lookupOptions.value.transmitters = data.transmitters || [];
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOAD_ERROR'));
  } finally {
    isLoadingTransmitters.value = false;
  }
};

const setBuilderStep = step => {
  const stepIndex = BUILDER_STEP_IDS.indexOf(step);
  if (stepIndex < 0) return;

  builderStep.value = step;
  maxVisitedBuilderStepIndex.value = Math.max(
    maxVisitedBuilderStepIndex.value,
    stepIndex
  );
};

const selectBuilderStep = step => {
  const stepIndex = BUILDER_STEP_IDS.indexOf(step);
  if (stepIndex < 0 || stepIndex > maxVisitedBuilderStepIndex.value) return;

  builderStep.value = step;
};

const startNewBroadcast = () => {
  currentView.value = 'builder';
  selectedBroadcast.value = null;
  resetBuilderData();
  setBuilderStep('setup');
};

const backToHistory = () => {
  currentView.value = 'history';
  selectedBroadcast.value = null;
  fetchBroadcasts();
};

const requestCloseBuilder = () => {
  if (!hasBuilderChanges.value) {
    backToHistory();
    return;
  }

  discardBuilderDialogRef.value?.open();
};

const discardBuilder = () => {
  discardBuilderDialogRef.value?.close();
  backToHistory();
};

const changeHistoryPage = async page => {
  clearHistorySelection();
  historyMeta.value.page = page;
  await fetchBroadcasts(page);
};

const changeHistoryPerPage = async perPage => {
  historyPerPage.value = Number(perPage) || HISTORY_PER_PAGE;
  clearHistorySelection();
  historyMeta.value.page = 1;
  await fetchBroadcasts(1);
};

const refreshHistory = async () => {
  clearHistorySelection();
  await fetchBroadcasts(historyMeta.value.page);
};

const clearHistorySelection = () => {
  selectedHistoryBroadcastIds.value = [];
};

const isHistoryBroadcastSelected = broadcastId =>
  selectedHistoryBroadcastIdSet.value.has(broadcastId);

const toggleHistoryBroadcast = (broadcast, selected) => {
  if (!broadcast.deletable) return;

  const ids = new Set(selectedHistoryBroadcastIds.value);
  if (selected) ids.add(broadcast.id);
  else ids.delete(broadcast.id);
  selectedHistoryBroadcastIds.value = [...ids];
};

const toggleHistoryPage = selected => {
  selectedHistoryBroadcastIds.value = selected
    ? deletableHistoryBroadcasts.value.map(broadcast => broadcast.id)
    : [];
};

const requestBroadcastDeletion = broadcast => {
  if (!broadcast.deletable) return;

  pendingHistoryDeletionIds.value = [broadcast.id];
  deleteBroadcastDialogRef.value?.open();
};

const requestSelectedBroadcastDeletion = () => {
  if (!selectedHistoryCount.value) return;

  pendingHistoryDeletionIds.value = [...selectedHistoryBroadcastIds.value];
  deleteBroadcastDialogRef.value?.open();
};

const resetHistoryDeletion = () => {
  pendingHistoryDeletionIds.value = [];
};

const confirmHistoryDeletion = async () => {
  const ids = [...pendingHistoryDeletionIds.value];
  if (!ids.length) return;

  isDeletingBroadcasts.value = true;
  try {
    if (ids.length === 1) {
      await messageBroadcastAPI.deleteBroadcast(ids[0]);
    } else {
      await messageBroadcastAPI.deleteBroadcasts(ids);
    }

    const remainingTotal = Math.max(historyMeta.value.total - ids.length, 0);
    const totalPages = Math.max(
      Math.ceil(remainingTotal / historyPerPage.value),
      1
    );
    const nextPage = Math.min(historyMeta.value.page, totalPages);

    deleteBroadcastDialogRef.value?.close();
    resetHistoryDeletion();
    clearHistorySelection();
    useAlert(
      ids.length === 1
        ? t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DELETE_ONE_SUCCESS')
        : t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DELETE_MANY_SUCCESS', {
            count: ids.length,
          })
    );
    await fetchBroadcasts(nextPage);
  } catch (error) {
    const errorCode = error.response?.data?.error;
    useAlert(
      errorCode === 'broadcast_in_progress'
        ? t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DELETE_ACTIVE_ERROR')
        : t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DELETE_ERROR')
    );
  } finally {
    isDeletingBroadcasts.value = false;
  }
};

const openBroadcast = async broadcast => {
  isLoadingBroadcastDetail.value = true;
  selectedBroadcast.value = { ...broadcast, recipients: [] };
  broadcastDetailDialogRef.value?.open();
  try {
    const { data } = await messageBroadcastAPI.getBroadcast(broadcast.id);
    selectedBroadcast.value = data;
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DETAIL_LOAD_ERROR'));
    broadcastDetailDialogRef.value?.close();
  } finally {
    isLoadingBroadcastDetail.value = false;
  }
};

const closeBroadcastDetail = () => {
  broadcastDetailDialogRef.value?.close();
};

const resetBroadcastDetail = () => {
  selectedBroadcast.value = null;
  isLoadingBroadcastDetail.value = false;
};

const sendSelectedBroadcast = async () => {
  if (!selectedBroadcast.value || !canSendSelectedBroadcast.value) return;

  isSendingBroadcast.value = true;
  try {
    const { data } = await messageBroadcastAPI.sendBroadcast(
      selectedBroadcast.value.id
    );
    selectedBroadcast.value = data;
    await fetchBroadcasts(historyMeta.value.page);
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SEND_STARTED'));
  } finally {
    isSendingBroadcast.value = false;
  }
};

const selectDispatchMode = mode => {
  dispatchMode.value = mode;
  sourceMode.value = mode === 'single' ? 'search' : '';
  searchMode.value = 'direct';
  selectedCustomers.value = [];
  selectedGroupIds.value = [];
  clearResultSelection();
  resetSearchResults();
};

const goToRecipients = () => {
  if (!canContinueSetup.value) return;

  setBuilderStep('recipients');
  if (dispatchMode.value === 'single') sourceMode.value = 'search';
  ensureLookupCatalogForMode(searchMode.value);
};

const chooseSource = mode => {
  if (sourceMode.value !== mode) {
    selectedCustomers.value = [];
    selectedGroupIds.value = [];
  }
  sourceMode.value = mode;
  resetSearchResults();
  ensureLookupCatalogForMode(searchMode.value);
};

const goToContent = async () => {
  if (!canGoToContent.value) return;

  if (isGroupSource.value) {
    const loaded = await addSelectedGroupsToRecipients();
    if (!loaded) return;
  }

  setBuilderStep('content');
};

const goToDelivery = () => {
  if (!canGoToDelivery.value) return;
  setBuilderStep('delivery');
};

const goToReview = () => {
  if (!canGoToReview.value) return;
  setBuilderStep('review');
};

const selectDelivery = mode => {
  draftForm.value.conversationMode =
    mode === 'direct' ? 'direct' : 'close_after_send';
};

function resetBuilderData() {
  maxVisitedBuilderStepIndex.value = 0;
  dispatchMode.value = '';
  sourceMode.value = '';
  searchMode.value = 'direct';
  recipientSelectionPurpose.value = 'recipients';
  templateQuery.value = '';
  selectedCustomers.value = [];
  selectedGroupIds.value = [];
  groupName.value = '';
  resetDraftData();
  resetSearchResults();
}

function resetDraftData() {
  draftForm.value = {
    inboxId: defaultInboxId.value,
    templateId: '',
    conversationMode: 'direct',
  };
  templateOptions.value = [];
  variableRows.value = [];
}

function resetSearchResults() {
  customers.value = [];
  clearResultSelection();
  resultPage.value = 1;
  resultMeta.value = {
    has_more: false,
    source_total: 0,
    source_returned: 0,
    total: 0,
    total_pages: 0,
    per_page: resultPerPage.value,
    search_token: '',
    cache_hit: false,
  };
  activeSearch.value = null;
  foundCustomersQuery.value = '';
}

function ensureLookupCatalogForMode(mode) {
  if (mode === 'contracts' && lookupOptions.value.plans.length === 0) {
    fetchPlans();
  }

  if (
    mode === 'concentrators' &&
    concentratorFilterCapabilities.value.pops &&
    lookupOptions.value.pops.length === 0
  ) {
    fetchPops();
  }

  if (
    mode === 'concentrators' &&
    concentratorFilterCapabilities.value.transmitters &&
    lookupOptions.value.transmitters.length === 0
  ) {
    fetchTransmitters();
  }
}

function buildPreviewPayload(
  page,
  limit = DEFAULT_PER_PAGE,
  search = activeSearch.value,
  refresh = false
) {
  const payload = {
    mode: search?.mode || searchMode.value,
    page,
    limit,
    filters: search?.filters || buildFilters(),
  };
  const query = foundCustomersQuery.value.trim();
  if (query) payload.query = query;
  if (refresh) payload.refresh = true;

  return payload;
}

function buildFilters() {
  if (searchMode.value === 'contracts') {
    const filters = {
      contract_statuses: compactArray([contractFilters.value.contractStatus]),
      plan_ids: contractFilters.value.selectedPlanIds,
      client_active: emptyToUndefined(contractFilters.value.clientActive),
      state_id: contractFilters.value.stateId,
      city_id: contractFilters.value.cityId,
    };
    if (contractFilterCapabilities.value.internet_status) {
      filters.internet_statuses = compactArray([
        contractFilters.value.internetStatus,
      ]);
    }
    return filters;
  }

  if (searchMode.value === 'concentrators') {
    const filters = {
      client_active: emptyToUndefined(concentratorFilters.value.clientActive),
    };
    const capabilities = concentratorFilterCapabilities.value;
    if (capabilities.manual_concentrator_ids) {
      filters.concentrator_ids = splitNumberList(
        concentratorFilters.value.concentratorIds
      );
    }
    if (capabilities.pops) {
      filters.pop_ids = concentratorFilters.value.selectedPopIds;
    }
    if (capabilities.transmitters) {
      filters.transmitter_ids =
        concentratorFilters.value.selectedTransmitterIds;
    }
    if (capabilities.transmission_interfaces) {
      filters.transmission_interface_ids = splitNumberList(
        concentratorFilters.value.transmissionInterfaceIds
      );
    }
    if (capabilities.ftth_boxes) {
      filters.ftth_box_ids = splitNumberList(
        concentratorFilters.value.ftthBoxIds
      );
    }
    if (capabilities.transmitter_ports) {
      filters.transmitter_port_ids = splitNumberList(
        concentratorFilters.value.transmitterPortIds
      );
    }
    return filters;
  }

  return {
    name: directFilters.value.name,
    state_id: directFilters.value.stateId,
    city_id: directFilters.value.cityId,
    active: emptyToUndefined(directFilters.value.active),
    street: directFilters.value.street,
    zip_code: directFilters.value.zipCode,
    neighborhood: directFilters.value.neighborhood,
  };
}

function compactArray(items) {
  return items.filter(Boolean);
}

function emptyToUndefined(value) {
  return value === '' ? undefined : value;
}

function splitNumberList(value) {
  return value
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
}

const snapshotFilters = filters =>
  Object.fromEntries(
    Object.entries(filters).map(([key, value]) => [
      key,
      Array.isArray(value) ? [...value] : value,
    ])
  );

const waitForRecipientSearch = delay =>
  new Promise(resolve => {
    window.setTimeout(resolve, delay);
  });

const fetchRecipientSearchPage = async (payload, requestId, attempt = 0) => {
  const { data } = await messageBroadcastAPI.previewRecipients(payload);
  if (data.status !== 'building') return data;
  if (attempt >= 120) throw new Error('recipient_search_timeout');

  const retryDelay = data.retry_after ?? 1;
  if (retryDelay > 0) await waitForRecipientSearch(retryDelay * 1000);
  if (requestId !== recipientSearchRequestId) return null;

  const pollPayload = { ...payload };
  delete pollPayload.refresh;
  return fetchRecipientSearchPage(pollPayload, requestId, attempt + 1);
};

const searchCustomers = async (
  page = 1,
  searchOverride = null,
  { refresh = false } = {}
) => {
  recipientSearchRequestId += 1;
  const requestId = recipientSearchRequestId;
  isSearching.value = true;
  try {
    const search =
      searchOverride ||
      (page === 1 || !activeSearch.value
        ? {
            mode: searchMode.value,
            filters: snapshotFilters(buildFilters()),
          }
        : activeSearch.value);
    const data = await fetchRecipientSearchPage(
      buildPreviewPayload(page, resultPerPage.value, search, refresh),
      requestId
    );
    if (!data || requestId !== recipientSearchRequestId) return;
    if (data.status === 'failed') throw new Error('recipient_search_failed');

    activeSearch.value = search;
    customers.value = (data.customers || []).map(customer => ({
      ...customer,
      search_context: resultContextLabel.value,
    }));
    resultPage.value = data.page || page;
    resultMeta.value = {
      has_more: Boolean(data.has_more),
      source_total: data.source_total || 0,
      source_returned: data.source_returned || 0,
      total: data.total || 0,
      total_pages: data.total_pages || 0,
      per_page: data.per_page || resultPerPage.value,
      search_token: data.search_token || '',
      cache_hit: Boolean(data.cache_hit),
    };
  } catch {
    if (requestId === recipientSearchRequestId) {
      useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SEARCH_ERROR'));
    }
  } finally {
    if (requestId === recipientSearchRequestId) isSearching.value = false;
  }
};

const runFilteredCustomerSearch = () => {
  window.clearTimeout(foundCustomersSearchTimer);
  foundCustomersQuery.value = '';
  clearResultSelection();
  searchCustomers(1, null, { refresh: true });
};

const scheduleFoundCustomersSearch = () => {
  window.clearTimeout(foundCustomersSearchTimer);
  if (!activeSearch.value) return;

  foundCustomersSearchTimer = window.setTimeout(() => {
    clearResultSelection();
    searchCustomers(1, activeSearch.value);
  }, LOOKUP_DEBOUNCE_MS);
};

const clearFoundCustomersSearch = () => {
  window.clearTimeout(foundCustomersSearchTimer);
  foundCustomersQuery.value = '';
  clearResultSelection();
  if (activeSearch.value) searchCustomers(1, activeSearch.value);
};

const changeResultPerPage = async value => {
  resultPerPage.value = Number(value);
  resultPage.value = 1;
  if (resultSelectionScope.value !== 'all') clearResultSelection();
  if (!activeSearch.value) return;

  await searchCustomers(1, activeSearch.value);
};

const selectedPlanNames = computed(() =>
  lookupOptions.value.plans
    .filter(plan => contractFilters.value.selectedPlanIds.includes(plan.id))
    .map(plan => plan.name)
);

const resultContextLabel = computed(() => {
  if (searchMode.value === 'contracts') {
    return selectedPlanNames.value.join(', ');
  }

  if (searchMode.value === 'concentrators') {
    return splitNumberList(concentratorFilters.value.concentratorIds).join(
      ', '
    );
  }

  return '';
});

const planOptions = computed(() =>
  lookupOptions.value.plans.map(plan => ({
    value: plan.id,
    label: plan.name,
  }))
);

const popOptions = computed(() =>
  lookupOptions.value.pops.map(pop => ({
    value: pop.id,
    label: pop.name,
  }))
);

const transmitterOptions = computed(() =>
  lookupOptions.value.transmitters.map(transmitter => ({
    value: transmitter.id,
    label: transmitter.name,
  }))
);

const isCustomerSelected = customer =>
  resultSelectionScope.value === 'all' ||
  resultSelectedSet.value.has(customer.external_id);

const clearResultSelection = () => {
  resultSelectionScope.value = 'none';
  selectedResultIds.value = [];
};

const toggleCustomer = customer => {
  if (dispatchMode.value === 'single') {
    resultSelectionScope.value = 'page';
    selectedResultIds.value = isCustomerSelected(customer)
      ? []
      : [customer.external_id];
    if (selectedResultIds.value.length === 0)
      resultSelectionScope.value = 'none';
    return;
  }

  if (resultSelectionScope.value === 'all') {
    resultSelectionScope.value = 'page';
    selectedResultIds.value = customers.value
      .map(item => item.external_id)
      .filter(id => id !== customer.external_id);
    return;
  }

  resultSelectionScope.value = 'page';
  selectedResultIds.value = isCustomerSelected(customer)
    ? selectedResultIds.value.filter(id => id !== customer.external_id)
    : [...selectedResultIds.value, customer.external_id];
  if (selectedResultIds.value.length === 0) resultSelectionScope.value = 'none';
};

const toggleCurrentPageSelection = () => {
  if (isCurrentPageSelected.value && resultSelectionScope.value !== 'all') {
    clearResultSelection();
    return;
  }

  resultSelectionScope.value = 'page';
  selectedResultIds.value = customers.value.map(
    customer => customer.external_id
  );
};

const selectAllResults = () => {
  if (!resultMeta.value.total) return;

  resultSelectionScope.value = 'all';
  selectedResultIds.value = [];
};

const addSelectedResultsToRecipients = () => {
  if (dispatchMode.value === 'single') {
    selectedCustomers.value = selectedResultCustomers.value.slice(0, 1);
    clearResultSelection();
    return;
  }

  mergeRecipients(selectedResultCustomers.value);
  clearResultSelection();
};

const addAllResultsToRecipients = async () => {
  const customersToAdd = await loadAllResultCustomers();
  if (!customersToAdd) return false;

  mergeRecipients(customersToAdd);
  clearResultSelection();
  return true;
};

const loadAllResultCustomers = async () => {
  if (!resultMeta.value.total || !activeSearch.value) return null;

  isAddingAllResults.value = true;
  try {
    const bulkPageSize = 500;
    const pageCount = Math.ceil(resultMeta.value.total / bulkPageSize);
    const pages = Array.from({ length: pageCount }, (_, index) => index + 1);
    const responses = await fetchCachedRecipientPages(pages, bulkPageSize);

    return responses.map(customer => ({
      ...customer,
      search_context: resultContextLabel.value,
    }));
  } finally {
    isAddingAllResults.value = false;
  }
};

async function fetchCachedRecipientPages(pages, perPage) {
  if (pages.length === 0) return [];

  const currentBatch = pages.slice(0, 3);
  const remainingPages = pages.slice(3);
  const batchResponses = await Promise.all(
    currentBatch.map(page =>
      messageBroadcastAPI.previewRecipients(
        buildPreviewPayload(page, perPage, activeSearch.value)
      )
    )
  );
  const customersInBatch = batchResponses.flatMap(
    response => response.data.customers || []
  );

  return [
    ...customersInBatch,
    ...(await fetchCachedRecipientPages(remainingPages, perPage)),
  ];
}

const addSelectedGroupsToRecipients = async () => {
  if (selectedGroups.value.length === 0) return false;

  isAddingGroups.value = true;
  try {
    const responses = await Promise.all(
      selectedGroups.value.map(group => messageBroadcastAPI.getGroup(group.id))
    );
    const members = responses.flatMap(response =>
      (response.data.members || []).map(member => groupMemberToCustomer(member))
    );
    selectedCustomers.value = [];
    mergeRecipients(members);
    return selectedCustomers.value.length > 0;
  } finally {
    isAddingGroups.value = false;
  }
};

const mergeCustomerCollections = (currentCustomers, customersToAdd) => {
  const merged = new Map(
    currentCustomers.map(customer => [customer.external_id, customer])
  );
  customersToAdd.forEach(customer => {
    if (customer.external_id) merged.set(customer.external_id, customer);
  });
  return Array.from(merged.values());
};

function mergeRecipients(customersToAdd) {
  if (dispatchMode.value === 'single') {
    selectedCustomers.value = customersToAdd.slice(0, 1);
    return;
  }

  selectedCustomers.value = mergeCustomerCollections(
    selectedCustomers.value,
    customersToAdd
  );
}

const removeRecipient = customer => {
  selectedCustomers.value = selectedCustomers.value.filter(
    recipient => recipient.external_id !== customer.external_id
  );
};

const updateRecipient = updatedRecipient => {
  selectedCustomers.value = selectedCustomers.value.map(recipient =>
    recipient.external_id === updatedRecipient.external_id
      ? updatedRecipient
      : recipient
  );
};

const toggleGroup = group => {
  const groupId = String(group.id);
  selectedGroupIds.value = selectedGroupIds.value.includes(groupId)
    ? selectedGroupIds.value.filter(id => id !== groupId)
    : [...selectedGroupIds.value, groupId];
  selectedCustomers.value = [];
};

const resetGroupEditor = () => {
  groupEditorRequestId += 1;
  isLoadingGroupEditor.value = false;
  editingGroup.value = null;
  editingGroupName.value = '';
  editingGroupMembers.value = [];
};

const openGroupEditor = async group => {
  groupEditorRequestId += 1;
  const requestId = groupEditorRequestId;
  editingGroup.value = group;
  editingGroupName.value = group.name;
  editingGroupMembers.value = [];
  isLoadingGroupEditor.value = true;
  groupEditorDialogRef.value?.open();

  try {
    const { data } = await messageBroadcastAPI.getGroup(group.id);
    if (requestId !== groupEditorRequestId) return;

    editingGroup.value = data;
    editingGroupName.value = data.name;
    editingGroupMembers.value = (data.members || []).map(member =>
      groupMemberToCustomer(member)
    );
  } catch {
    if (requestId !== groupEditorRequestId) return;
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_LOAD_ERROR'));
    groupEditorDialogRef.value?.close();
  } finally {
    if (requestId === groupEditorRequestId) {
      isLoadingGroupEditor.value = false;
    }
  }
};

const closeGroupEditor = () => {
  resetGroupEditor();
};

const addGroupEditorMembers = () => {
  openRecipientSelection('group-edit');
};

const mergeGroupEditorMembers = customersToAdd => {
  editingGroupMembers.value = mergeCustomerCollections(
    editingGroupMembers.value,
    customersToAdd
  );
};

const removeGroupEditorMember = customer => {
  editingGroupMembers.value = editingGroupMembers.value.filter(
    member => member.external_id !== customer.external_id
  );
};

const updateGroupEditorMember = updatedCustomer => {
  editingGroupMembers.value = editingGroupMembers.value.map(member =>
    member.external_id === updatedCustomer.external_id
      ? updatedCustomer
      : member
  );
};

const saveGroupEditor = async () => {
  if (
    !editingGroup.value ||
    !editingGroupName.value.trim() ||
    isSavingGroupEditor.value
  ) {
    return;
  }

  isSavingGroupEditor.value = true;
  try {
    await messageBroadcastAPI.updateGroup(editingGroup.value.id, {
      name: editingGroupName.value.trim(),
      members: editingGroupMembers.value.map(customerToMemberPayload),
    });
    selectedCustomers.value = [];
    await fetchGroups();
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_UPDATED'));
    groupEditorDialogRef.value?.close();
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_UPDATE_ERROR'));
  } finally {
    isSavingGroupEditor.value = false;
  }
};

const saveGroup = async () => {
  if (!groupName.value || !hasSelectedResults.value) return false;

  isSavingGroup.value = true;
  try {
    const payload = {
      name: groupName.value,
    };
    if (resultSelectionScope.value === 'all') {
      payload.selection = {
        scope: 'all',
        search_token: resultMeta.value.search_token,
        query: foundCustomersQuery.value,
      };
    } else {
      payload.members = selectedResultCustomers.value.map(
        customerToMemberPayload
      );
    }

    await messageBroadcastAPI.createGroup(payload);
    groupName.value = '';
    clearResultSelection();
    await fetchGroups();
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_CREATED'));
    return true;
  } catch (error) {
    if (error.response?.data?.error === 'recipient_selection_expired') {
      useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SELECTION_EXPIRED'));
    } else {
      useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_CREATE_ERROR'));
    }
    return false;
  } finally {
    isSavingGroup.value = false;
  }
};

const openRecipientSelection = purpose => {
  recipientSelectionPurpose.value = purpose;
  groupName.value = '';
  clearResultSelection();
  ensureLookupCatalogForMode(searchMode.value);
  recipientSelectionDialogRef.value?.open();
};

const closeRecipientSelection = () => {
  clearResultSelection();
};

const confirmRecipientSelection = async () => {
  if (!hasSelectedResults.value) return;

  if (recipientSelectionPurpose.value === 'group') {
    const saved = await saveGroup();
    if (saved) recipientSelectionDialogRef.value?.close();
    return;
  }

  if (recipientSelectionPurpose.value === 'group-edit') {
    if (resultSelectionScope.value === 'all') {
      const customersToAdd = await loadAllResultCustomers();
      if (!customersToAdd) return;
      mergeGroupEditorMembers(customersToAdd);
    } else {
      mergeGroupEditorMembers(selectedResultCustomers.value);
    }
    clearResultSelection();
    recipientSelectionDialogRef.value?.close();
    return;
  }

  if (resultSelectionScope.value === 'all') {
    const added = await addAllResultsToRecipients();
    if (added) recipientSelectionDialogRef.value?.close();
    return;
  }

  addSelectedResultsToRecipients();
  recipientSelectionDialogRef.value?.close();
};

const broadcastPayload = () => {
  const template = selectedTemplate.value;
  return {
    inbox_id: draftForm.value.inboxId,
    dispatch_mode: dispatchMode.value,
    source_type:
      dispatchMode.value === 'bulk' && sourceMode.value === 'groups'
        ? 'group'
        : 'selection',
    template_name: template.name,
    template_language: template.language,
    conversation_mode: draftForm.value.conversationMode,
    template_variables: templateVariablesPayload(),
    recipients: selectedCustomers.value.map(customerToRecipientPayload),
  };
};

const submitNewBroadcast = async ({ sendNow }) => {
  const canSubmit = sendNow
    ? canSendNewBroadcast.value
    : canCreateBroadcast.value;
  if (!canSubmit || isSubmittingBroadcast.value) return;

  const loadingState = sendNow ? isSendingBroadcastNow : isCreatingBroadcast;
  loadingState.value = true;
  try {
    const payload = broadcastPayload();
    if (sendNow) payload.send_now = true;
    const { data } = await messageBroadcastAPI.createBroadcast(payload);
    useAlert(
      sendNow
        ? t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SEND_STARTED')
        : t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DRAFT_CREATED', {
            id: data.id,
          })
    );
    historyMeta.value.page = 1;
    backToHistory();
  } finally {
    loadingState.value = false;
  }
};

const createBroadcastDraft = () => submitNewBroadcast({ sendNow: false });
const sendBroadcastNow = () => submitNewBroadcast({ sendNow: true });

function templateVariablesPayload() {
  return variableRows.value.reduce((payload, row) => {
    if (!row.key) return payload;
    payload[row.key] = compactObject(
      row.type === 'fixed'
        ? {
            type: 'fixed',
            value: singleLineValue(row.value),
            component_type: row.component_type,
            button_type: row.button_type,
            button_index: row.button_index,
            parameter_key: row.parameter_key,
            parameter_type: row.parameter_type,
            media_type: row.media_type,
          }
        : {
            type: 'customer_field',
            field: row.field,
            component_type: row.component_type,
            button_type: row.button_type,
            button_index: row.button_index,
            parameter_key: row.parameter_key,
            parameter_type: row.parameter_type,
            media_type: row.media_type,
          }
    );
    return payload;
  }, {});
}

function compactObject(object) {
  return Object.fromEntries(
    Object.entries(object).filter(
      ([, value]) => value !== undefined && value !== ''
    )
  );
}

const templateVariableValuesForCustomer = customer =>
  variableRows.value.reduce((values, row) => {
    if (row.type !== 'customer_field' || !row.key) return values;
    values[row.key] = singleLineValue(customerFieldValue(customer, row.field));
    return values;
  }, {});

function customerFieldValue(customer, field) {
  const fieldMap = {
    name: customer.name,
    document: customer.document,
    address: customer.address,
    city_name: customer.city_name,
    state: customer.state,
    primary_phone: customer.phone_selection?.primary_phone,
    fallback_phone: customer.phone_selection?.fallback_phone,
  };

  return fieldMap[field] || '';
}

const updateFixedVariable = (row, value) => {
  row.value = singleLineValue(value);
};

const templateOptionLabel = template =>
  [template.language, template.category, template.status]
    .filter(Boolean)
    .join(' · ');

const componentTypeLabel = type => {
  const normalizedType = String(type || 'UNKNOWN').toUpperCase();
  if (normalizedType === 'HEADER') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.TEMPLATE_COMPONENTS.HEADER');
  }
  if (normalizedType === 'BODY') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.TEMPLATE_COMPONENTS.BODY');
  }
  if (normalizedType === 'FOOTER') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.TEMPLATE_COMPONENTS.FOOTER');
  }
  if (normalizedType === 'BUTTONS') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.TEMPLATE_COMPONENTS.BUTTONS');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.TEMPLATE_COMPONENTS.UNKNOWN');
};

const templateVariableComponentLabel = row =>
  row.component_type ? componentTypeLabel(row.component_type) : '';

const templateVariableLabel = row => {
  if (isCopyCodeButtonVariable(row)) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.COPY_CODE_BUTTON', {
      button: row.button_text || row.label,
    });
  }
  if (isDynamicUrlButtonVariable(row)) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.DYNAMIC_URL_BUTTON', {
      button: row.button_text || row.label,
    });
  }
  if (!isMediaHeaderVariable(row)) return row.label;

  const mediaType = String(row.media_type || '').toUpperCase();
  if (mediaType === 'IMAGE') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.HEADER_IMAGE_URL');
  }
  if (mediaType === 'VIDEO') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.HEADER_VIDEO_URL');
  }
  if (mediaType === 'DOCUMENT') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.HEADER_DOCUMENT_URL');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.HEADER_MEDIA_URL');
};

const fixedVariablePlaceholder = row =>
  isDynamicUrlButtonVariable(row)
    ? t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.DYNAMIC_URL_PLACEHOLDER')
    : t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.FIXED_PLACEHOLDER');

const buildVariableRows = template => {
  variableRows.value = (template?.variables || []).map(variable => {
    const mediaHeader = isMediaHeaderVariable(variable);
    const fixedOnly = mediaHeader || isCopyCodeButtonVariable(variable);

    return {
      key: variable.key,
      label: variable.label,
      component_type: variable.component_type,
      button_type: variable.button_type,
      button_index: variable.button_index,
      button_text: variable.button_text,
      parameter_key: variable.parameter_key,
      parameter_type: variable.parameter_type,
      media_type: variable.media_type,
      type: fixedOnly ? 'fixed' : 'customer_field',
      field: fixedOnly ? '' : 'name',
      value: '',
    };
  });
};

function customerToMemberPayload(customer) {
  return {
    external_customer_id: customer.external_id,
    customer_name: customer.name,
    primary_phone: customer.phone_selection?.primary_phone,
    fallback_phone: customer.phone_selection?.fallback_phone,
    city: customer.city_name,
    state: customer.state,
    active: customer.active,
  };
}

function customerToRecipientPayload(customer) {
  return {
    external_customer_id: customer.external_id,
    customer_name: customer.name,
    primary_phone: customer.phone_selection?.primary_phone,
    fallback_phone: customer.phone_selection?.fallback_phone,
    template_variable_values: templateVariableValuesForCustomer(customer),
  };
}

function groupMemberToCustomer(member) {
  return {
    external_id: member.external_customer_id,
    name: member.customer_name,
    city_name: member.city,
    state: member.state,
    active: member.active,
    phone_selection: {
      primary_phone: member.primary_phone,
      fallback_phone: member.fallback_phone,
      deliverable: Boolean(member.primary_phone || member.fallback_phone),
    },
  };
}

const formatDate = value => {
  if (!value) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.COMMON.NOT_INFORMED');
  }

  try {
    return new Intl.DateTimeFormat(dateTimeLocale.value, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(value));
  } catch {
    return new Intl.DateTimeFormat('pt-BR', {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(value));
  }
};

const statusLabel = status => {
  if (status === 'queued') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.QUEUED');
  }
  if (status === 'running') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.RUNNING');
  }
  if (status === 'completed') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.COMPLETED');
  }
  if (status === 'failed') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.FAILED');
  }
  if (status === 'cancelled') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.CANCELLED');
  }
  if (status === 'pending') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.PENDING');
  }
  if (status === 'processing') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.PROCESSING');
  }
  if (status === 'sent') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.SENT');
  }
  if (status === 'accepted') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.ACCEPTED');
  }
  if (status === 'delivered') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.DELIVERED');
  }
  if (status === 'read') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.READ');
  }
  if (status === 'uncertain') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.UNCERTAIN');
  }
  if (status === 'skipped') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.SKIPPED');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.DRAFT');
};

const statusClass = status =>
  ({
    draft: 'bg-n-slate-3 text-n-slate-11',
    queued: 'bg-n-amber-3 text-n-amber-11',
    running: 'bg-n-blue-3 text-n-blue-11',
    completed: 'bg-n-teal-3 text-n-teal-11',
    failed: 'bg-n-ruby-3 text-n-ruby-11',
    cancelled: 'bg-n-slate-3 text-n-slate-11',
  })[status] || 'bg-n-slate-3 text-n-slate-11';

const dispatchLabel = mode => {
  if (mode === 'single') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.SINGLE_TITLE');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.BULK_TITLE');
};

const conversationModeLabel = mode => {
  if (mode === 'direct') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.DIRECT_TITLE');
  }
  if (mode === 'keep_open') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.KEEP_OPEN');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CLOSE_AFTER_SEND');
};

const customerAddressLabel = customer =>
  [customer.address, customer.neighborhood].filter(Boolean).join(' · ');

const customerLocationLabel = customer =>
  [customer.city_name, customer.state, customer.search_context]
    .filter(Boolean)
    .join(' · ');

const goToResultPage = page => {
  if (page < 1) return;
  if (resultSelectionScope.value !== 'all') clearResultSelection();
  searchCustomers(page);
};

watch(
  () => directFilters.value.stateId,
  () => {
    directFilters.value.cityId = '';
    cityQuery.value = '';
    lookupOptions.value.cities = [];
    window.clearTimeout(cityLookupTimer);
    cityLookupTimer = window.setTimeout(fetchCities, LOOKUP_DEBOUNCE_MS);
  }
);

watch(
  () => contractFilters.value.stateId,
  () => {
    contractFilters.value.cityId = '';
    contractCityQuery.value = '';
    lookupOptions.value.contractCities = [];
    window.clearTimeout(contractCityLookupTimer);
    contractCityLookupTimer = window.setTimeout(
      fetchContractCities,
      LOOKUP_DEBOUNCE_MS
    );
  }
);

watch(stateQuery, () => {
  window.clearTimeout(stateLookupTimer);
  stateLookupTimer = window.setTimeout(fetchStates, LOOKUP_DEBOUNCE_MS);
});

watch(cityQuery, () => {
  window.clearTimeout(cityLookupTimer);
  cityLookupTimer = window.setTimeout(fetchCities, LOOKUP_DEBOUNCE_MS);
});

watch(contractCityQuery, () => {
  window.clearTimeout(contractCityLookupTimer);
  contractCityLookupTimer = window.setTimeout(
    fetchContractCities,
    LOOKUP_DEBOUNCE_MS
  );
});

watch(
  () => contractFilters.value.planQuery,
  () => {
    window.clearTimeout(planLookupTimer);
    planLookupTimer = window.setTimeout(fetchPlans, LOOKUP_DEBOUNCE_MS);
  }
);

watch(
  () => concentratorFilters.value.popQuery,
  () => {
    window.clearTimeout(popLookupTimer);
    popLookupTimer = window.setTimeout(fetchPops, LOOKUP_DEBOUNCE_MS);
  }
);

watch(
  () => concentratorFilters.value.transmitterQuery,
  () => {
    window.clearTimeout(transmitterLookupTimer);
    transmitterLookupTimer = window.setTimeout(
      fetchTransmitters,
      LOOKUP_DEBOUNCE_MS
    );
  }
);

watch(
  () => draftForm.value.inboxId,
  () => {
    fetchTemplates();
  }
);

watch(selectedTemplate, template => {
  buildVariableRows(template);
});

watch(searchMode, mode => {
  resetSearchResults();
  ensureLookupCatalogForMode(mode);
});

onMounted(boot);
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full max-w-none flex-1 flex-col overflow-y-auto bg-n-background"
  >
    <section
      data-testid="message-broadcast-page-content"
      class="mx-auto flex w-full max-w-none flex-col gap-5 px-4 py-6 sm:px-6 lg:px-8"
    >
      <header class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.TITLE') }}
          </h1>
          <p class="mt-1 max-w-3xl text-sm text-n-slate-11">
            {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DESCRIPTION') }}
          </p>
        </div>
        <span
          v-if="activeConnection"
          class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs font-medium text-n-slate-11"
        >
          {{ activeConnection.name }}
        </span>
      </header>

      <div v-if="isBooting" class="flex min-h-64 items-center justify-center">
        <Spinner />
      </div>

      <section
        v-else-if="!hasActiveConnection"
        class="rounded-xl bg-n-alpha-1 p-6 text-sm text-n-slate-11 outline outline-1 outline-n-weak"
      >
        {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.EMPTY_ERP') }}
      </section>

      <template v-else-if="currentView === 'history'">
        <section class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DESCRIPTION') }}
            </p>
          </div>
          <Button
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.NEW_BROADCAST')"
            icon="i-lucide-plus"
            @click="startNewBroadcast"
          />
        </section>

        <section
          class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-2"
        >
          <div
            v-if="selectedHistoryCount"
            data-testid="history-selection-toolbar"
            class="flex min-h-14 flex-wrap items-center gap-2 border-b border-n-weak bg-n-alpha-1 px-4 py-3"
          >
            <div class="flex min-w-0 flex-wrap items-center gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.SELECTION.COUNT', {
                    count: selectedHistoryCount,
                  })
                }}
              </span>
              <Button
                color="slate"
                variant="faded"
                size="sm"
                :label="
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.SELECTION.CLEAR')
                "
                @click="clearHistorySelection"
              />
              <Button
                data-testid="history-delete-selected"
                icon="i-lucide-trash-2"
                color="ruby"
                size="sm"
                :label="
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.SELECTION.DELETE')
                "
                @click="requestSelectedBroadcastDeletion"
              />
            </div>
          </div>

          <div
            v-if="isLoadingHistory"
            class="flex min-h-48 items-center justify-center"
          >
            <Spinner />
          </div>
          <div
            v-else-if="broadcasts.length === 0"
            class="p-6 text-sm text-n-slate-11"
          >
            {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.EMPTY') }}
          </div>
          <div v-else class="overflow-x-auto">
            <table
              class="w-full min-w-[74rem] border-collapse text-left text-sm"
            >
              <thead class="bg-n-alpha-1 text-xs font-medium text-n-slate-11">
                <tr>
                  <th class="w-12 px-4 py-3">
                    <input
                      data-testid="history-select-page"
                      type="checkbox"
                      :checked="isHistoryPageSelected"
                      :disabled="deletableHistoryBroadcasts.length === 0"
                      :aria-label="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.SELECTION.SELECT_PAGE'
                        )
                      "
                      @change="toggleHistoryPage($event.target.checked)"
                    />
                  </th>
                  <th class="px-4 py-3">
                    {{
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.BROADCAST'
                      )
                    }}
                  </th>
                  <th class="px-4 py-3">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.TYPE') }}
                  </th>
                  <th class="px-4 py-3">
                    {{
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.RECIPIENTS'
                      )
                    }}
                  </th>
                  <th class="px-4 py-3">
                    {{
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.DELIVERY')
                    }}
                  </th>
                  <th class="px-4 py-3">
                    {{
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.STATUS')
                    }}
                  </th>
                  <th class="px-4 py-3">
                    {{
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.AUTHOR')
                    }}
                  </th>
                  <th class="px-4 py-3">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.DATE') }}
                  </th>
                  <th class="w-20 px-4 py-3 text-right">
                    {{
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.ACTIONS')
                    }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak">
                <tr
                  v-for="broadcast in broadcasts"
                  :key="broadcast.id"
                  class="hover:bg-n-alpha-1"
                >
                  <td class="px-4 py-3">
                    <input
                      type="checkbox"
                      :checked="isHistoryBroadcastSelected(broadcast.id)"
                      :disabled="!broadcast.deletable"
                      :aria-label="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.SELECTION.SELECT_BROADCAST',
                          { name: broadcast.template_name }
                        )
                      "
                      @change="
                        toggleHistoryBroadcast(broadcast, $event.target.checked)
                      "
                    />
                  </td>
                  <td class="px-4 py-3">
                    <p
                      class="m-0 max-w-sm truncate font-medium text-n-slate-12"
                    >
                      {{ broadcast.template_name }}
                    </p>
                  </td>
                  <td class="px-4 py-3 text-n-slate-11">
                    {{ dispatchLabel(broadcast.dispatch_mode) }}
                  </td>
                  <td class="px-4 py-3 text-n-slate-11">
                    {{ broadcast.recipients_count }}
                  </td>
                  <td class="px-4 py-3 text-n-slate-11">
                    {{ conversationModeLabel(broadcast.conversation_mode) }}
                  </td>
                  <td class="px-4 py-3">
                    <span
                      class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                      :class="statusClass(broadcast.status)"
                    >
                      {{ statusLabel(broadcast.status) }}
                    </span>
                  </td>
                  <td class="max-w-48 px-4 py-3 text-n-slate-11">
                    <span class="block truncate">
                      {{
                        broadcast.created_by?.name ||
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.UNKNOWN_AUTHOR'
                        )
                      }}
                    </span>
                  </td>
                  <td class="whitespace-nowrap px-4 py-3 text-n-slate-11">
                    {{ formatDate(broadcast.created_at) }}
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex justify-end gap-1">
                      <Button
                        v-tooltip.top="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.VIEW')
                        "
                        icon="i-lucide-eye"
                        color="slate"
                        variant="ghost"
                        size="sm"
                        :aria-label="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.VIEW')
                        "
                        @click="openBroadcast(broadcast)"
                      />
                      <span
                        v-tooltip.top="
                          broadcast.deletable
                            ? t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.DELETE'
                              )
                            : t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.DELETE_ACTIVE'
                              )
                        "
                        class="inline-flex"
                      >
                        <Button
                          icon="i-lucide-trash-2"
                          color="ruby"
                          variant="ghost"
                          size="sm"
                          :disabled="!broadcast.deletable"
                          :aria-label="
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.DELETE'
                            )
                          "
                          @click="requestBroadcastDeletion(broadcast)"
                        />
                      </span>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <HistoryPaginationFooter
            v-if="historyMeta.total > 0"
            :current-page="historyMeta.page"
            :total-items="historyMeta.total"
            :items-per-page="historyMeta.per_page"
            :page-size-options="HISTORY_PAGE_SIZES"
            :default-page-size="HISTORY_PER_PAGE"
            :is-refreshing="isLoadingHistory"
            @update:current-page="changeHistoryPage"
            @update:items-per-page="changeHistoryPerPage"
            @refresh="refreshHistory"
          />
        </section>
      </template>

      <BroadcastWorkspace
        v-else
        :title="t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.TITLE')"
        :close-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.CLOSE')"
        :steps="stepItems"
        :active-step="builderStep"
        @close="requestCloseBuilder"
        @select-step="selectBuilderStep"
      >
        <section
          v-if="builderStep === 'setup'"
          class="grid gap-5 rounded-xl bg-n-alpha-1 p-5 outline outline-1 outline-n-weak"
          data-testid="message-broadcast-setup-step"
        >
          <div>
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DISPATCH.TITLE') }}
            </h2>
            <div class="mt-4 grid gap-3 md:grid-cols-2">
              <button
                v-for="option in dispatchOptions"
                :key="option.id"
                type="button"
                class="grid grid-cols-[auto,minmax(0,1fr)] content-start gap-3 rounded-lg p-4 text-left outline outline-1 transition-colors"
                :class="
                  dispatchMode === option.id
                    ? 'bg-n-alpha-2 outline-n-brand'
                    : 'bg-n-alpha-1 outline-n-weak hover:outline-n-brand'
                "
                :aria-pressed="dispatchMode === option.id"
                @click="selectDispatchMode(option.id)"
              >
                <span :class="option.icon" class="mt-0.5 size-5 text-n-brand" />
                <span class="min-w-0">
                  <span class="block font-semibold text-n-slate-12">
                    {{ option.title }}
                  </span>
                  <span class="mt-1 block text-sm text-n-slate-11">
                    {{ option.description }}
                  </span>
                </span>
              </button>
            </div>
          </div>

          <div
            class="grid gap-2 border-t border-n-weak pt-5 md:grid-cols-[minmax(0,1fr)_auto] md:items-end"
          >
            <label class="grid min-w-0 gap-1 text-sm text-n-slate-11">
              {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.INBOX') }}
              <IbsoftSelect v-model="draftForm.inboxId">
                <option value="">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SELECT_INBOX') }}
                </option>
                <option
                  v-for="inbox in inboxOptions"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </IbsoftSelect>
            </label>
            <Button
              icon="i-lucide-arrow-right"
              :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.CONTINUE')"
              :disabled="!canContinueSetup"
              @click="goToRecipients"
            />
          </div>
        </section>

        <template v-if="builderStep === 'recipients'">
          <section
            data-testid="message-broadcast-recipient-step"
            class="flex min-w-0 flex-col gap-4"
          >
            <div class="flex items-center justify-between gap-3">
              <Button
                variant="ghost"
                icon="i-lucide-arrow-left"
                :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK')"
                @click="selectBuilderStep('setup')"
              />
              <span class="text-sm text-n-slate-11">
                {{ dispatchLabel(dispatchMode) }}
              </span>
            </div>

            <section
              v-if="dispatchMode === 'bulk'"
              class="grid gap-3 md:grid-cols-2"
              data-testid="message-broadcast-source-options"
            >
              <button
                v-for="option in sourceOptions"
                :key="option.id"
                type="button"
                class="grid grid-cols-[auto,minmax(0,1fr)] gap-3 rounded-lg p-4 text-left outline outline-1 transition-colors"
                :class="
                  sourceMode === option.id
                    ? 'bg-n-alpha-2 outline-n-brand'
                    : 'bg-n-alpha-1 outline-n-weak hover:outline-n-brand'
                "
                :aria-pressed="sourceMode === option.id"
                @click="chooseSource(option.id)"
              >
                <span :class="option.icon" class="mt-0.5 size-5 text-n-brand" />
                <span class="min-w-0">
                  <span class="block font-medium text-n-slate-12">
                    {{ option.title }}
                  </span>
                  <span class="mt-1 block text-sm text-n-slate-11">
                    {{ option.description }}
                  </span>
                </span>
              </button>
            </section>

            <div class="flex min-w-0 flex-col gap-4">
              <section
                v-if="dispatchMode === 'bulk' && sourceMode === 'groups'"
                class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 class="font-semibold text-n-slate-12">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.TITLE') }}
                    </h2>
                    <p class="text-sm text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.DESCRIPTION')
                      }}
                    </p>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <Button
                      v-if="dispatchMode === 'bulk'"
                      variant="secondary"
                      icon="i-lucide-list-plus"
                      :label="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_TITLE'
                        )
                      "
                      @click="openRecipientSelection('group')"
                    />
                  </div>
                </div>
                <div class="mt-4 grid gap-2 md:grid-cols-2">
                  <article
                    v-for="group in groups"
                    :key="group.id"
                    class="grid grid-cols-[minmax(0,1fr),auto] items-center rounded-lg outline outline-1 transition-colors"
                    :class="
                      selectedGroupIds.includes(String(group.id))
                        ? 'bg-n-alpha-2 outline-n-brand'
                        : 'bg-n-alpha-1 outline-n-weak'
                    "
                  >
                    <button
                      type="button"
                      class="grid min-w-0 grid-cols-[minmax(0,1fr),auto] items-center gap-3 rounded-lg p-3 text-left"
                      :aria-pressed="
                        selectedGroupIds.includes(String(group.id))
                      "
                      @click="toggleGroup(group)"
                    >
                      <span class="min-w-0">
                        <span
                          class="block truncate font-medium text-n-slate-12"
                        >
                          {{ group.name }}
                        </span>
                        <span class="text-xs text-n-slate-11">
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.MEMBERS', {
                              count: group.members_count,
                            })
                          }}
                        </span>
                      </span>
                      <span
                        class="flex size-6 items-center justify-center rounded-full outline outline-1"
                        :class="
                          selectedGroupIds.includes(String(group.id))
                            ? 'bg-n-brand/10 text-n-brand outline-n-brand'
                            : 'text-transparent outline-n-weak'
                        "
                      >
                        <span class="i-lucide-check size-4" />
                      </span>
                    </button>
                    <Button
                      variant="ghost"
                      size="sm"
                      icon="i-lucide-pencil"
                      class="mr-2"
                      :data-testid="`edit-group-${group.id}`"
                      :title="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.ACTION')
                      "
                      :aria-label="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.ACTION')
                      "
                      @click="openGroupEditor(group)"
                    />
                  </article>
                </div>

                <div
                  class="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-n-weak pt-4"
                  data-testid="selected-groups-summary"
                >
                  <div
                    class="inline-flex items-center gap-2 text-sm text-n-slate-11"
                  >
                    <span class="i-lucide-users-round size-4 text-n-brand" />
                    {{
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.SELECTION_SUMMARY',
                        {
                          groups: selectedGroupIds.length,
                        }
                      )
                    }}
                  </div>
                  <Button
                    icon="i-lucide-arrow-right"
                    :label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.CONTINUE')
                    "
                    :disabled="selectedGroupIds.length === 0"
                    :is-loading="isAddingGroups"
                    @click="goToContent"
                  />
                </div>
              </section>

              <div v-if="sourceMode === 'search'" class="flex justify-end">
                <Button
                  icon="i-lucide-user-plus"
                  :label="
                    dispatchMode === 'single'
                      ? t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SELECT_RECIPIENT'
                        )
                      : t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.ADD_CLIENTS')
                  "
                  @click="openRecipientSelection('recipients')"
                />
              </div>

              <RecipientSelectionDialog
                ref="recipientSelectionDialogRef"
                v-model:group-name="groupName"
                :purpose="recipientSelectionPurpose"
                :selection-count="selectedResultCount"
                :current-page-count="customers.length"
                :total-count="resultMeta.total"
                :selection-scope="resultSelectionScope"
                :allow-select-all="dispatchMode === 'bulk'"
                :is-loading="isConfirmingRecipientSelection"
                @close="closeRecipientSelection"
                @confirm="confirmRecipientSelection"
                @select-page="toggleCurrentPageSelection"
                @select-all="selectAllResults"
                @clear-selection="clearResultSelection"
              >
                <template #filters>
                  <section
                    class="rounded-lg bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
                  >
                    <div
                      class="flex flex-wrap items-center justify-between gap-3"
                    >
                      <div>
                        <h2 class="font-semibold text-n-slate-12">
                          {{
                            recipientSelectionPurpose === 'group'
                              ? t(
                                  'IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.CREATE_FROM_FILTERS'
                                )
                              : t('IBSOFT_THEME.MESSAGE_BROADCAST.SEARCH.TITLE')
                          }}
                        </h2>
                        <p class="text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.SEARCH.DESCRIPTION'
                            )
                          }}
                        </p>
                      </div>
                    </div>

                    <SearchModeMenu
                      v-if="dispatchMode === 'bulk'"
                      v-model="searchMode"
                      class="mt-5"
                      :options="modeOptions"
                    />

                    <div class="mt-4">
                      <div
                        v-if="searchMode === 'direct'"
                        class="grid gap-3 md:grid-cols-3"
                      >
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.NAME') }}
                          <input
                            v-model="directFilters.name"
                            :class="inputClass"
                          />
                        </label>
                        <label
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STATE')
                          }}
                          <LookupSingleSelect
                            v-model="directFilters.stateId"
                            v-model:query="stateQuery"
                            :options="stateOptions"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_STATE'
                              )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.STATES_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                            :loading="isLoadingStates"
                          />
                        </label>
                        <label
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CITY') }}
                          <LookupSingleSelect
                            v-model="directFilters.cityId"
                            v-model:query="cityQuery"
                            :options="cityOptions"
                            :placeholder="
                              directFilters.stateId
                                ? t(
                                    'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_CITY'
                                  )
                                : t(
                                    'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECT_STATE_FIRST'
                                  )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.CITIES_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                            :loading="isLoadingCities"
                            :disabled="!directFilters.stateId"
                          />
                        </label>
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CLIENT_STATUS'
                            )
                          }}
                          <IbsoftSelect v-model="directFilters.active">
                            <option
                              v-for="option in customerActiveOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </IbsoftSelect>
                        </label>
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STREET')
                          }}
                          <input
                            v-model="directFilters.street"
                            :class="inputClass"
                          />
                        </label>
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.NEIGHBORHOOD'
                            )
                          }}
                          <input
                            v-model="directFilters.neighborhood"
                            :class="inputClass"
                          />
                        </label>
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ZIP_CODE')
                          }}
                          <input
                            v-model="directFilters.zipCode"
                            :class="inputClass"
                          />
                        </label>
                      </div>

                      <div
                        v-if="searchMode === 'contracts'"
                        class="grid gap-3 md:grid-cols-3"
                      >
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CLIENT_STATUS'
                            )
                          }}
                          <IbsoftSelect v-model="contractFilters.clientActive">
                            <option
                              v-for="option in customerActiveOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </IbsoftSelect>
                        </label>
                        <label
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STATE')
                          }}
                          <LookupSingleSelect
                            v-model="contractFilters.stateId"
                            v-model:query="stateQuery"
                            :options="stateOptions"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_STATE'
                              )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.STATES_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                            :loading="isLoadingStates"
                          />
                        </label>
                        <label
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CITY') }}
                          <LookupSingleSelect
                            v-model="contractFilters.cityId"
                            v-model:query="contractCityQuery"
                            :options="contractCityOptions"
                            :placeholder="
                              contractFilters.stateId
                                ? t(
                                    'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_CITY'
                                  )
                                : t(
                                    'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECT_STATE_FIRST'
                                  )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.CITIES_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                            :loading="isLoadingCities"
                            :disabled="!contractFilters.stateId"
                          />
                        </label>
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CONTRACT_STATUS'
                            )
                          }}
                          <IbsoftSelect
                            v-model="contractFilters.contractStatus"
                          >
                            <option
                              v-for="option in contractStatusOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </IbsoftSelect>
                        </label>
                        <label
                          v-if="contractFilterCapabilities.internet_status"
                          class="grid gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.INTERNET_STATUS'
                            )
                          }}
                          <IbsoftSelect
                            v-model="contractFilters.internetStatus"
                          >
                            <option
                              v-for="option in internetStatusOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </IbsoftSelect>
                        </label>
                        <label
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.PLAN') }}
                          <LookupMultiSelect
                            v-model="contractFilters.selectedPlanIds"
                            v-model:query="contractFilters.planQuery"
                            :options="planOptions"
                            :loading="isLoadingPlans"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.PLANS_PLACEHOLDER'
                              )
                            "
                            :selected-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED',
                                {
                                  count: contractFilters.selectedPlanIds.length,
                                }
                              )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.PLANS_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                          />
                        </label>
                      </div>

                      <div
                        v-if="searchMode === 'concentrators'"
                        class="grid gap-3 md:grid-cols-3"
                      >
                        <label class="grid gap-1 text-sm text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CLIENT_STATUS'
                            )
                          }}
                          <IbsoftSelect
                            v-model="concentratorFilters.clientActive"
                          >
                            <option
                              v-for="option in customerActiveOptions"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </IbsoftSelect>
                        </label>
                        <label
                          v-if="
                            concentratorFilterCapabilities.manual_concentrator_ids
                          "
                          class="grid gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CONCENTRATOR'
                            )
                          }}
                          <input
                            v-model="concentratorFilters.concentratorIds"
                            :class="inputClass"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                              )
                            "
                          />
                        </label>
                        <label
                          v-if="concentratorFilterCapabilities.pops"
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.POP_IDS')
                          }}
                          <LookupMultiSelect
                            v-model="concentratorFilters.selectedPopIds"
                            v-model:query="concentratorFilters.popQuery"
                            :options="popOptions"
                            :loading="isLoadingPops"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.POPS_PLACEHOLDER'
                              )
                            "
                            :selected-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED',
                                {
                                  count:
                                    concentratorFilters.selectedPopIds.length,
                                }
                              )
                            "
                            :search-placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.POPS_SEARCH'
                              )
                            "
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                          />
                        </label>
                        <label
                          v-if="concentratorFilterCapabilities.transmitters"
                          class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                        >
                          {{ transmitterLookupText.label }}
                          <LookupMultiSelect
                            v-model="concentratorFilters.selectedTransmitterIds"
                            v-model:query="concentratorFilters.transmitterQuery"
                            :options="transmitterOptions"
                            :loading="isLoadingTransmitters"
                            :placeholder="transmitterLookupText.placeholder"
                            :selected-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED',
                                {
                                  count:
                                    concentratorFilters.selectedTransmitterIds
                                      .length,
                                }
                              )
                            "
                            :search-placeholder="transmitterLookupText.search"
                            :empty-state="
                              t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                            "
                            :loading-label="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING'
                              )
                            "
                          />
                        </label>
                        <label
                          v-if="
                            concentratorFilterCapabilities.transmission_interfaces
                          "
                          class="grid gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMISSION_INTERFACE'
                            )
                          }}
                          <input
                            v-model="
                              concentratorFilters.transmissionInterfaceIds
                            "
                            :class="inputClass"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                              )
                            "
                          />
                        </label>
                        <label
                          v-if="concentratorFilterCapabilities.ftth_boxes"
                          class="grid gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.FTTH_BOX')
                          }}
                          <input
                            v-model="concentratorFilters.ftthBoxIds"
                            :class="inputClass"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                              )
                            "
                          />
                        </label>
                        <label
                          v-if="
                            concentratorFilterCapabilities.transmitter_ports
                          "
                          class="grid gap-1 text-sm text-n-slate-11"
                        >
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMITTER_PORT'
                            )
                          }}
                          <input
                            v-model="concentratorFilters.transmitterPortIds"
                            :class="inputClass"
                            :placeholder="
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                              )
                            "
                          />
                        </label>
                      </div>
                    </div>

                    <div class="mt-4 flex justify-end">
                      <Button
                        :label="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEARCH')
                        "
                        icon="i-lucide-search"
                        :is-loading="isSearching"
                        @click="runFilteredCustomerSearch"
                      />
                    </div>
                  </section>
                </template>

                <template #results>
                  <section
                    class="rounded-lg bg-n-alpha-1 outline outline-1 outline-n-weak"
                  >
                    <div
                      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-4 py-3"
                    >
                      <div>
                        <h2 class="font-medium text-n-slate-12">
                          {{
                            t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.TITLE')
                          }}
                        </h2>
                        <p class="text-xs text-n-slate-11">
                          {{
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.PAGE_INFO',
                              {
                                page: resultPage,
                                count: customers.length,
                              }
                            )
                          }}
                        </p>
                      </div>
                      <div class="flex flex-wrap gap-2">
                        <PageSizeSelect
                          :model-value="resultPerPage"
                          :default-value="DEFAULT_PER_PAGE"
                          @update:model-value="changeResultPerPage"
                        />
                      </div>
                    </div>

                    <div
                      v-if="activeSearch"
                      class="border-b border-n-weak px-4 py-3"
                    >
                      <label class="relative block w-full max-w-lg">
                        <span
                          class="pointer-events-none absolute left-3 top-1/2 z-10 i-lucide-search size-4 -translate-y-1/2 text-n-slate-10"
                        />
                        <input
                          v-model="foundCustomersQuery"
                          class="!px-10"
                          :class="inputClass"
                          :placeholder="
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SEARCH_PLACEHOLDER'
                            )
                          "
                          :aria-label="
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SEARCH_LABEL'
                            )
                          "
                          @input="scheduleFoundCustomersSearch"
                        />
                        <button
                          v-if="foundCustomersQuery"
                          type="button"
                          class="absolute right-3 top-1/2 z-10 flex size-5 -translate-y-1/2 items-center justify-center rounded text-n-slate-10 hover:text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                          :title="
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.CLEAR_SEARCH'
                            )
                          "
                          :aria-label="
                            t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.CLEAR_SEARCH'
                            )
                          "
                          @click="clearFoundCustomersSearch"
                        >
                          <span class="i-lucide-x size-4" />
                        </button>
                      </label>
                    </div>

                    <div
                      v-if="isSearching"
                      class="flex min-h-48 items-center justify-center"
                    >
                      <Spinner />
                    </div>
                    <div
                      v-else-if="customers.length === 0"
                      class="p-6 text-sm text-n-slate-11"
                    >
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.EMPTY') }}
                    </div>
                    <div v-else class="divide-y divide-n-weak">
                      <button
                        v-for="customer in customers"
                        :key="customer.external_id"
                        type="button"
                        class="grid w-full grid-cols-[auto,minmax(0,1fr),auto] items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-1"
                        @click="toggleCustomer(customer)"
                      >
                        <input
                          :type="
                            dispatchMode === 'single' ? 'radio' : 'checkbox'
                          "
                          class="size-4"
                          :checked="isCustomerSelected(customer)"
                          @click.stop="toggleCustomer(customer)"
                        />
                        <span class="min-w-0">
                          <span
                            class="block truncate font-medium text-n-slate-12"
                          >
                            {{ customer.name }}
                          </span>
                          <span class="block truncate text-xs text-n-slate-11">
                            {{ customerAddressLabel(customer) }}
                          </span>
                          <span class="block truncate text-xs text-n-slate-10">
                            {{ customerLocationLabel(customer) }}
                          </span>
                        </span>
                        <span class="grid gap-0.5 text-right text-xs">
                          <span class="text-n-slate-11">
                            {{
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.PRIMARY_PHONE_VALUE',
                                {
                                  phone:
                                    customer.phone_selection?.primary_phone ||
                                    t(
                                      'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.NO_PHONE'
                                    ),
                                }
                              )
                            }}
                          </span>
                          <span
                            v-if="customer.phone_selection?.fallback_phone"
                            class="text-n-slate-10"
                          >
                            {{
                              t(
                                'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FALLBACK_PHONE_VALUE',
                                {
                                  phone:
                                    customer.phone_selection.fallback_phone,
                                }
                              )
                            }}
                          </span>
                        </span>
                      </button>
                    </div>

                    <PaginationFooter
                      v-if="resultMeta.total > resultMeta.per_page"
                      class="[&_.bg-n-input-background]:!bg-n-alpha-3 [&_.bg-n-input-background]:!text-n-slate-12 [&_.bg-n-input-background]:outline [&_.bg-n-input-background]:outline-1 [&_.bg-n-input-background]:outline-n-weak"
                      :current-page="resultPage"
                      :total-items="resultMeta.total"
                      :items-per-page="resultMeta.per_page"
                      current-page-info="IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.PAGINATION"
                      @update:current-page="goToResultPage"
                    />
                  </section>
                </template>
              </RecipientSelectionDialog>
            </div>

            <div v-if="!isGroupSource" class="flex min-w-0 flex-col gap-4">
              <RecipientTable
                :recipients="selectedCustomers"
                :can-continue="canGoToContent"
                @continue="goToContent"
                @remove="removeRecipient"
                @update="updateRecipient"
              />
            </div>
          </section>
        </template>

        <template v-if="builderStep === 'content'">
          <section
            class="grid gap-4"
            data-testid="message-broadcast-content-step"
          >
            <div
              class="grid min-w-0 gap-4 lg:grid-cols-[minmax(0,1fr)_24rem]"
              data-testid="message-broadcast-content-layout"
            >
              <div
                class="min-w-0 rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <h2 class="font-semibold text-n-slate-12">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTENT.TITLE') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTENT.DESCRIPTION') }}
                </p>

                <div class="relative mt-4">
                  <span
                    class="pointer-events-none absolute left-3 top-1/2 i-lucide-search size-4 -translate-y-1/2 text-n-slate-10"
                  />
                  <input
                    v-model="templateQuery"
                    class="!px-10"
                    :class="inputClass"
                    :placeholder="
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.CONTENT.SEARCH_TEMPLATE'
                      )
                    "
                  />
                </div>

                <div
                  v-if="isLoadingTemplates"
                  class="flex min-h-40 items-center justify-center"
                >
                  <Spinner />
                </div>
                <div
                  v-else-if="filteredTemplates.length === 0"
                  class="mt-4 rounded-lg bg-n-alpha-1 p-4 text-sm text-n-slate-11 outline outline-1 outline-n-weak"
                >
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.CONTENT.EMPTY_TEMPLATES')
                  }}
                </div>
                <div
                  v-else
                  class="mt-4 grid max-h-80 gap-2 overflow-y-auto pr-1"
                >
                  <button
                    v-for="template in filteredTemplates"
                    :key="template.id"
                    type="button"
                    class="grid gap-1 rounded-lg p-3 text-left outline outline-1 transition-colors"
                    :class="
                      String(draftForm.templateId) === String(template.id)
                        ? 'bg-n-alpha-2 outline-n-brand'
                        : 'bg-n-alpha-1 outline-n-weak hover:outline-n-brand'
                    "
                    :aria-pressed="
                      String(draftForm.templateId) === String(template.id)
                    "
                    @click="draftForm.templateId = template.id"
                  >
                    <span class="font-medium text-n-slate-12">
                      {{ template.name }}
                    </span>
                    <span class="text-xs text-n-slate-10">
                      {{ templateOptionLabel(template) }}
                    </span>
                  </button>
                </div>

                <div class="mt-6">
                  <div class="flex items-center justify-between gap-3">
                    <div>
                      <h3 class="font-medium text-n-slate-12">
                        {{
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.TITLE')
                        }}
                      </h3>
                      <p class="text-sm text-n-slate-11">
                        {{
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.AUTO_DESCRIPTION'
                          )
                        }}
                      </p>
                    </div>
                  </div>

                  <div
                    v-if="selectedTemplate && variableRows.length === 0"
                    class="mt-3 rounded-lg bg-n-alpha-1 p-3 text-sm text-n-slate-11 outline outline-1 outline-n-weak"
                  >
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.EMPTY') }}
                  </div>

                  <div v-else class="mt-3 grid gap-3">
                    <div
                      v-for="row in variableRows"
                      :key="row.key"
                      class="grid gap-2 rounded-lg bg-n-alpha-1 p-3 outline outline-1 outline-n-weak md:grid-cols-[120px,1fr,1fr]"
                    >
                      <div class="grid gap-1 text-sm">
                        <span class="font-medium text-n-slate-12">
                          {{ templateVariableLabel(row) }}
                        </span>
                        <span class="text-xs text-n-slate-10">
                          {{ templateVariableComponentLabel(row) }}
                        </span>
                      </div>
                      <input
                        v-if="isMediaHeaderVariable(row)"
                        :value="row.value"
                        type="url"
                        inputmode="url"
                        class="md:col-span-2"
                        :class="inputClass"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.MEDIA_URL_PLACEHOLDER'
                          )
                        "
                        @input="updateFixedVariable(row, $event.target.value)"
                        @keydown.enter.prevent
                      />
                      <input
                        v-else-if="isCopyCodeButtonVariable(row)"
                        :value="row.value"
                        type="text"
                        :maxlength="COPY_CODE_MAX_LENGTH"
                        class="md:col-span-2"
                        :class="inputClass"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.COPY_CODE_PLACEHOLDER'
                          )
                        "
                        @input="updateFixedVariable(row, $event.target.value)"
                        @keydown.enter.prevent
                      />
                      <template v-else>
                        <IbsoftSelect v-model="row.type">
                          <option
                            v-for="option in variableTypeOptions"
                            :key="option.value"
                            :value="option.value"
                          >
                            {{ option.label }}
                          </option>
                        </IbsoftSelect>
                        <IbsoftSelect
                          v-if="row.type === 'customer_field'"
                          v-model="row.field"
                        >
                          <option
                            v-for="option in customerFieldOptions"
                            :key="option.value"
                            :value="option.value"
                          >
                            {{ option.label }}
                          </option>
                        </IbsoftSelect>
                      </template>
                      <input
                        v-if="
                          !isMediaHeaderVariable(row) &&
                          !isCopyCodeButtonVariable(row) &&
                          row.type === 'fixed'
                        "
                        :value="row.value"
                        :class="inputClass"
                        :placeholder="fixedVariablePlaceholder(row)"
                        @input="updateFixedVariable(row, $event.target.value)"
                        @keydown.enter.prevent
                      />
                    </div>
                  </div>
                </div>
              </div>

              <aside class="min-w-0 lg:sticky lg:top-4 lg:self-start">
                <TemplatePreview
                  :template="selectedTemplate"
                  :variables="variableRows"
                />
              </aside>
            </div>

            <section
              class="grid gap-4 rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak md:grid-cols-[minmax(0,1fr)_auto] md:items-end"
              data-testid="message-broadcast-content-summary"
            >
              <div>
                <h2 class="font-medium text-n-slate-12">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SUMMARY') }}
                </h2>
                <dl class="mt-3 grid gap-3 text-sm sm:grid-cols-2">
                  <div class="flex justify-between gap-3">
                    <dt class="text-n-slate-11">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.TITLE') }}
                    </dt>
                    <dd class="font-medium text-n-slate-12">
                      {{ selectedCustomers.length }}
                    </dd>
                  </div>
                  <div class="flex justify-between gap-3">
                    <dt class="text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.DELIVERABLE')
                      }}
                    </dt>
                    <dd class="font-medium text-n-slate-12">
                      {{ selectedPhoneCount }}
                    </dd>
                  </div>
                </dl>
              </div>
              <div class="flex flex-wrap justify-end gap-2">
                <Button
                  variant="secondary"
                  icon="i-lucide-arrow-left"
                  :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK')"
                  @click="selectBuilderStep('recipients')"
                />
                <Button
                  icon="i-lucide-arrow-right"
                  :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.CONTINUE')"
                  :disabled="!canGoToDelivery"
                  @click="goToDelivery"
                />
              </div>
            </section>
          </section>
        </template>

        <template v-if="builderStep === 'delivery'">
          <section
            class="grid gap-5 rounded-xl bg-n-alpha-1 p-5 outline outline-1 outline-n-weak"
            data-testid="message-broadcast-delivery-step"
          >
            <div>
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DELIVERY.DESCRIPTION') }}
              </p>
            </div>

            <div class="grid gap-3 md:grid-cols-2">
              <button
                v-for="option in deliveryOptions"
                :key="option.id"
                type="button"
                class="grid grid-cols-[auto,minmax(0,1fr)] content-start gap-3 rounded-lg p-4 text-left outline outline-1 transition-colors"
                :class="
                  (option.id === 'direct' && !usesConversation) ||
                  (option.id === 'conversation' && usesConversation)
                    ? 'bg-n-alpha-2 outline-n-brand'
                    : 'bg-n-alpha-1 outline-n-weak hover:outline-n-brand'
                "
                :aria-pressed="
                  (option.id === 'direct' && !usesConversation) ||
                  (option.id === 'conversation' && usesConversation)
                "
                @click="selectDelivery(option.id)"
              >
                <span :class="option.icon" class="mt-0.5 size-5 text-n-brand" />
                <span class="min-w-0">
                  <span class="block font-semibold text-n-slate-12">
                    {{ option.title }}
                  </span>
                  <span class="mt-1 block text-sm text-n-slate-11">
                    {{ option.description }}
                  </span>
                </span>
              </button>
            </div>

            <div
              v-if="usesConversation"
              class="grid gap-3 border-t border-n-weak pt-5 md:grid-cols-2"
            >
              <button
                v-for="option in conversationModeOptions"
                :key="option.value"
                type="button"
                class="rounded-lg px-4 py-3 text-left text-sm font-medium outline outline-1 transition-colors"
                :class="
                  draftForm.conversationMode === option.value
                    ? 'bg-n-alpha-2 text-n-slate-12 outline-n-brand'
                    : 'bg-n-alpha-1 text-n-slate-11 outline-n-weak hover:outline-n-brand'
                "
                :aria-pressed="draftForm.conversationMode === option.value"
                @click="draftForm.conversationMode = option.value"
              >
                {{ option.label }}
              </button>
            </div>

            <div
              class="flex flex-wrap justify-between gap-2 border-t border-n-weak pt-5"
            >
              <Button
                variant="secondary"
                icon="i-lucide-arrow-left"
                :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK')"
                @click="selectBuilderStep('content')"
              />
              <Button
                icon="i-lucide-arrow-right"
                :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.CONTINUE')"
                :disabled="!canGoToReview"
                @click="goToReview"
              />
            </div>
          </section>
        </template>

        <template v-if="builderStep === 'review'">
          <section
            class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_420px]"
            data-testid="message-broadcast-review-step"
          >
            <div
              class="rounded-xl bg-n-alpha-1 p-5 outline outline-1 outline-n-weak"
            >
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TITLE') }}
              </h2>
              <dl class="mt-5 grid gap-4 text-sm md:grid-cols-2">
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SEND_TYPE') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ dispatchLabel(dispatchMode) }}
                  </dd>
                </div>
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.INBOX') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ selectedInbox?.name }}
                  </dd>
                </div>
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.TITLE') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ selectedCustomers.length }}
                  </dd>
                </div>
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.DELIVERABLE') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ selectedPhoneCount }}
                  </dd>
                </div>
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE') }}
                  </dt>
                  <dd class="break-words font-medium text-n-slate-12">
                    {{ selectedTemplate?.name }}
                  </dd>
                </div>
                <div class="grid gap-1">
                  <dt class="text-n-slate-10">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.DELIVERY') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ conversationModeLabel(draftForm.conversationMode) }}
                  </dd>
                </div>
              </dl>

              <div
                class="mt-5 grid grid-cols-[auto,minmax(0,1fr)] gap-3 rounded-lg bg-n-alpha-2 p-3 text-sm text-n-slate-11"
              >
                <span
                  class="i-lucide-phone-forwarded mt-0.5 size-4 text-n-brand"
                />
                <span>
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.PHONE_PRIORITY')
                  }}
                </span>
              </div>

              <div
                class="mt-5 flex flex-wrap justify-between gap-2 border-t border-n-weak pt-5"
              >
                <Button
                  variant="secondary"
                  icon="i-lucide-arrow-left"
                  :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK')"
                  @click="selectBuilderStep('delivery')"
                />
                <div class="flex flex-wrap gap-2">
                  <Button
                    variant="secondary"
                    icon="i-lucide-file-plus-2"
                    :label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SAVE_DRAFT')
                    "
                    :disabled="!canCreateBroadcast || isSubmittingBroadcast"
                    :is-loading="isCreatingBroadcast"
                    @click="createBroadcastDraft"
                  />
                  <Button
                    icon="i-lucide-send"
                    :label="sendActionLabel"
                    :disabled="!canSendNewBroadcast || isSubmittingBroadcast"
                    :is-loading="isSendingBroadcastNow"
                    @click="sendBroadcastNow"
                  />
                </div>
              </div>
            </div>

            <TemplatePreview
              :template="selectedTemplate"
              :variables="variableRows"
            />
          </section>
        </template>
      </BroadcastWorkspace>
    </section>

    <GroupEditorDialog
      ref="groupEditorDialogRef"
      v-model:group-name="editingGroupName"
      :members="editingGroupMembers"
      :is-loading="isLoadingGroupEditor"
      :is-saving="isSavingGroupEditor"
      @add="addGroupEditorMembers"
      @close="closeGroupEditor"
      @remove="removeGroupEditorMember"
      @update="updateGroupEditorMember"
      @save="saveGroupEditor"
    />

    <Dialog
      ref="broadcastDetailDialogRef"
      width="3xl"
      position="top"
      overflow-y-auto
      :title="selectedBroadcastTitle"
      :description="selectedBroadcastDescription"
      :show-cancel-button="false"
      :show-confirm-button="false"
      @close="resetBroadcastDetail"
    >
      <div
        v-if="isLoadingBroadcastDetail"
        class="flex min-h-64 items-center justify-center"
      >
        <Spinner />
      </div>

      <div
        v-else-if="selectedBroadcast"
        class="grid max-h-[65vh] gap-4 overflow-y-auto pr-1 md:grid-cols-[minmax(0,1fr)_16rem]"
      >
        <section
          class="min-w-0 overflow-hidden rounded-lg border border-n-weak bg-n-solid-2"
        >
          <div class="divide-y divide-n-weak">
            <article
              v-for="recipient in selectedBroadcastRecipients"
              :key="recipient.id"
              class="grid gap-3 px-4 py-3 sm:grid-cols-[minmax(0,1fr),auto]"
            >
              <div class="min-w-0">
                <p class="truncate font-medium text-n-slate-12">
                  {{ recipient.customer_name }}
                </p>
                <p class="truncate text-xs text-n-slate-11">
                  <template v-if="recipient.phone_used">
                    {{
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.PHONE_USED', {
                        phone: recipient.phone_used,
                      })
                    }}
                  </template>
                  <template v-else>
                    {{
                      recipient.primary_phone ||
                      recipient.fallback_phone ||
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.NO_PHONE')
                    }}
                  </template>
                </p>
                <p
                  v-if="recipient.error_message"
                  class="mt-1 truncate text-xs text-n-ruby-9"
                >
                  {{ recipient.error_message }}
                </p>
                <RouterLink
                  v-if="recipient.conversation_display_id"
                  class="mt-1 inline-flex text-xs font-medium text-n-brand"
                  :to="{
                    name: 'inbox_conversation',
                    params: {
                      accountId: $route.params.accountId,
                      conversation_id: recipient.conversation_display_id,
                    },
                  }"
                >
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.CONVERSATION', {
                      id: recipient.conversation_display_id,
                    })
                  }}
                </RouterLink>
              </div>
              <span
                class="self-start rounded-md px-2 py-1 text-xs font-medium"
                :class="statusClass(recipient.status)"
              >
                {{ statusLabel(recipient.status) }}
              </span>
            </article>
          </div>
        </section>

        <aside class="grid content-start gap-4">
          <section class="rounded-lg border border-n-weak bg-n-solid-2 p-4">
            <h2 class="font-medium text-n-slate-12">
              {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.SUMMARY') }}
            </h2>
            <dl class="mt-4 grid gap-3 text-sm">
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.AUTHOR') }}
                </dt>
                <dd class="break-words font-medium text-n-slate-12">
                  {{
                    selectedBroadcast.created_by?.name ||
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.TABLE.UNKNOWN_AUTHOR'
                    )
                  }}
                </dd>
              </div>
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SEND_TYPE') }}
                </dt>
                <dd class="font-medium text-n-slate-12">
                  {{ dispatchLabel(selectedBroadcast.dispatch_mode) }}
                </dd>
              </div>
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.STATUS') }}
                </dt>
                <dd class="font-medium text-n-slate-12">
                  {{ statusLabel(selectedBroadcast.status) }}
                </dd>
              </div>
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.TITLE') }}
                </dt>
                <dd class="font-medium text-n-slate-12">
                  {{ selectedBroadcast.recipients_count }}
                </dd>
              </div>
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CONVERSATION_MODE')
                  }}
                </dt>
                <dd class="font-medium text-n-slate-12">
                  {{
                    conversationModeLabel(selectedBroadcast.conversation_mode)
                  }}
                </dd>
              </div>
              <div class="grid gap-1">
                <dt class="text-xs text-n-slate-10">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.CREATED_AT') }}
                </dt>
                <dd class="font-medium text-n-slate-12">
                  {{ formatDate(selectedBroadcast.created_at) }}
                </dd>
              </div>
            </dl>
          </section>
        </aside>
      </div>

      <template #footer>
        <div class="flex w-full flex-wrap justify-end gap-2">
          <Button
            type="button"
            color="slate"
            variant="faded"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.CLOSE')"
            @click="closeBroadcastDetail"
          />
          <Button
            v-if="canSendSelectedBroadcast"
            type="button"
            icon="i-lucide-send"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEND_NOW')"
            :is-loading="isSendingBroadcast"
            @click="sendSelectedBroadcast"
          />
        </div>
      </template>
    </Dialog>

    <Dialog
      ref="deleteBroadcastDialogRef"
      type="alert"
      :title="historyDeletionTitle"
      :description="historyDeletionDescription"
      :confirm-button-label="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.CONFIRM')
      "
      :cancel-button-label="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.DELETE.CANCEL')
      "
      :is-loading="isDeletingBroadcasts"
      @confirm="confirmHistoryDeletion"
      @close="resetHistoryDeletion"
    />

    <Dialog
      ref="discardBuilderDialogRef"
      type="alert"
      :title="t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.DISCARD_TITLE')"
      :description="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.DISCARD_DESCRIPTION')
      "
      :confirm-button-label="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.DISCARD_CONFIRM')
      "
      :cancel-button-label="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.WORKSPACE.DISCARD_CANCEL')
      "
      @confirm="discardBuilder"
    />
  </main>
</template>
