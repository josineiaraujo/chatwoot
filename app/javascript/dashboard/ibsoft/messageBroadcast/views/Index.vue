<script setup>
/* eslint-disable no-use-before-define -- handlers are grouped by screen workflow */
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import erpAPI from 'dashboard/ibsoft/erp/api';
import LookupMultiSelect from '../components/LookupMultiSelect.vue';
import LookupSingleSelect from '../components/LookupSingleSelect.vue';
import PageSizeSelect from '../components/PageSizeSelect.vue';
import RecipientTable from '../components/RecipientTable.vue';
import SearchModeMenu from '../components/SearchModeMenu.vue';
import messageBroadcastAPI from '../api';

const { t, locale } = useI18n();
const store = useStore();

const LOOKUP_DEBOUNCE_MS = 350;
const DEFAULT_PER_PAGE = 10;
const singleLineValue = value =>
  String(value || '')
    .replace(/[\r\n]+/g, ' ')
    .trim();

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

const currentView = ref('history');
const builderStep = ref('source');
const sourceMode = ref('');
const searchMode = ref('direct');
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
const broadcasts = ref([]);
const selectedBroadcast = ref(null);
const groups = ref([]);
const customers = ref([]);
const templateOptions = ref([]);
const selectedResultIds = ref([]);
const selectedGroupIds = ref([]);
const selectedCustomers = ref([]);
const groupName = ref('');

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
  conversationMode: 'close_after_send',
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

const hasActiveConnection = computed(() => Boolean(activeConnection.value));
const hasRecipients = computed(() => selectedCustomers.value.length > 0);
const selectedPhoneCount = computed(
  () =>
    selectedCustomers.value.filter(
      customer => customer.phone_selection?.deliverable
    ).length
);

const stepItems = computed(() => [
  { id: 'source', label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.SOURCE') },
  {
    id: 'recipients',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.RECIPIENTS'),
  },
  { id: 'review', label: t('IBSOFT_THEME.MESSAGE_BROADCAST.STEPS.REVIEW') },
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

const modeOptions = computed(() => [
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
]);

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
]);

const inboxOptions = computed(() => {
  const inboxes = store.getters['inboxes/getInboxes'] || [];
  const whatsappInboxes = inboxes.filter(
    inbox => inbox.channel_type === 'Channel::Whatsapp'
  );

  return whatsappInboxes.length ? whatsappInboxes : inboxes;
});
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
const selectedTemplate = computed(() =>
  templateOptions.value.find(
    template => String(template.id) === String(draftForm.value.templateId)
  )
);
const selectedBroadcastRecipients = computed(
  () => selectedBroadcast.value?.recipients || []
);
const canSendSelectedBroadcast = computed(
  () => selectedBroadcast.value?.status === 'draft'
);

const hasSelectedResults = computed(() => selectedResultIds.value.length > 0);
const isCurrentPageSelected = computed(
  () =>
    customers.value.length > 0 &&
    customers.value.every(customer =>
      resultSelectedSet.value.has(customer.external_id)
    )
);
const canGoToReview = computed(() => hasRecipients.value);
const areTemplateVariablesConfigured = computed(() =>
  variableRows.value.every(row =>
    row.type === 'fixed' ? singleLineValue(row.value).length > 0 : row.field
  )
);
const canCreateBroadcast = computed(
  () =>
    draftForm.value.inboxId &&
    selectedTemplate.value &&
    areTemplateVariablesConfigured.value &&
    hasRecipients.value
);
const canSendNewBroadcast = computed(
  () => canCreateBroadcast.value && selectedPhoneCount.value > 0
);
const isSubmittingBroadcast = computed(
  () => isCreatingBroadcast.value || isSendingBroadcastNow.value
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
      fetchStates(),
    ]);
  } finally {
    isBooting.value = false;
  }
};

async function fetchErpStatus() {
  const { data } = await erpAPI.getConnections();
  activeConnection.value =
    data.connections?.find(connection => connection.active) || null;
}

async function fetchBroadcasts() {
  isLoadingHistory.value = true;
  try {
    const { data } = await messageBroadcastAPI.getBroadcasts();
    broadcasts.value = data.broadcasts || [];
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

const startNewBroadcast = () => {
  currentView.value = 'builder';
  builderStep.value = 'source';
  sourceMode.value = '';
  selectedBroadcast.value = null;
  resetBuilderData();
};

const backToHistory = () => {
  currentView.value = 'history';
  selectedBroadcast.value = null;
  fetchBroadcasts();
};

const openBroadcast = async broadcast => {
  currentView.value = 'detail';
  isLoadingBroadcastDetail.value = true;
  selectedBroadcast.value = null;
  try {
    const { data } = await messageBroadcastAPI.getBroadcast(broadcast.id);
    selectedBroadcast.value = data;
  } catch {
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.DETAIL_LOAD_ERROR'));
    backToHistory();
  } finally {
    isLoadingBroadcastDetail.value = false;
  }
};

const sendSelectedBroadcast = async () => {
  if (!selectedBroadcast.value || !canSendSelectedBroadcast.value) return;

  isSendingBroadcast.value = true;
  try {
    const { data } = await messageBroadcastAPI.sendBroadcast(
      selectedBroadcast.value.id
    );
    selectedBroadcast.value = data;
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.SEND_STARTED'));
  } finally {
    isSendingBroadcast.value = false;
  }
};

const chooseSource = mode => {
  sourceMode.value = mode;
  builderStep.value = 'recipients';
  resetSearchResults();
  ensureLookupCatalogForMode(searchMode.value);
};

const goToReview = () => {
  if (!canGoToReview.value) return;
  builderStep.value = 'review';
};

function resetBuilderData() {
  selectedCustomers.value = [];
  selectedGroupIds.value = [];
  groupName.value = '';
  resetDraftData();
  resetSearchResults();
}

function resetDraftData() {
  draftForm.value = {
    inboxId: '',
    templateId: '',
    conversationMode: 'close_after_send',
  };
  templateOptions.value = [];
  variableRows.value = [];
}

function resetSearchResults() {
  customers.value = [];
  selectedResultIds.value = [];
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

  if (mode === 'concentrators' && lookupOptions.value.pops.length === 0) {
    fetchPops();
  }

  if (
    mode === 'concentrators' &&
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
    return {
      contract_statuses: compactArray([contractFilters.value.contractStatus]),
      internet_statuses: compactArray([contractFilters.value.internetStatus]),
      plan_ids: contractFilters.value.selectedPlanIds,
      client_active: emptyToUndefined(contractFilters.value.clientActive),
      state_id: contractFilters.value.stateId,
      city_id: contractFilters.value.cityId,
    };
  }

  if (searchMode.value === 'concentrators') {
    return {
      concentrator_ids: splitNumberList(
        concentratorFilters.value.concentratorIds
      ),
      client_active: emptyToUndefined(concentratorFilters.value.clientActive),
      pop_ids: concentratorFilters.value.selectedPopIds,
      transmitter_ids: concentratorFilters.value.selectedTransmitterIds,
      transmission_interface_ids: splitNumberList(
        concentratorFilters.value.transmissionInterfaceIds
      ),
      ftth_box_ids: splitNumberList(concentratorFilters.value.ftthBoxIds),
      transmitter_port_ids: splitNumberList(
        concentratorFilters.value.transmitterPortIds
      ),
    };
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
    selectedResultIds.value = [];
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
  searchCustomers(1, null, { refresh: true });
};

const scheduleFoundCustomersSearch = () => {
  window.clearTimeout(foundCustomersSearchTimer);
  if (!activeSearch.value) return;

  foundCustomersSearchTimer = window.setTimeout(() => {
    searchCustomers(1, activeSearch.value);
  }, LOOKUP_DEBOUNCE_MS);
};

const clearFoundCustomersSearch = () => {
  window.clearTimeout(foundCustomersSearchTimer);
  foundCustomersQuery.value = '';
  if (activeSearch.value) searchCustomers(1, activeSearch.value);
};

const changeResultPerPage = async value => {
  resultPerPage.value = Number(value);
  resultPage.value = 1;
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
  resultSelectedSet.value.has(customer.external_id);

const toggleCustomer = customer => {
  selectedResultIds.value = isCustomerSelected(customer)
    ? selectedResultIds.value.filter(id => id !== customer.external_id)
    : [...selectedResultIds.value, customer.external_id];
};

const toggleCurrentPageSelection = () => {
  selectedResultIds.value = isCurrentPageSelected.value
    ? []
    : customers.value.map(customer => customer.external_id);
};

const addSelectedResultsToRecipients = () => {
  mergeRecipients(selectedResultCustomers.value);
  selectedResultIds.value = [];
};

const addAllResultsToRecipients = async () => {
  if (!resultMeta.value.total || !activeSearch.value) return;

  isAddingAllResults.value = true;
  try {
    const bulkPageSize = 500;
    const pageCount = Math.ceil(resultMeta.value.total / bulkPageSize);
    const pages = Array.from({ length: pageCount }, (_, index) => index + 1);
    const responses = await fetchCachedRecipientPages(pages, bulkPageSize);

    mergeRecipients(
      responses.map(customer => ({
        ...customer,
        search_context: resultContextLabel.value,
      }))
    );
    selectedResultIds.value = [];
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

const addSelectedGroupsToRecipients = () => {
  const members = selectedGroups.value.flatMap(group =>
    group.members.map(member => groupMemberToCustomer(member))
  );
  mergeRecipients(members);
  selectedGroupIds.value = [];
};

function mergeRecipients(customersToAdd) {
  const merged = new Map(
    selectedCustomers.value.map(customer => [customer.external_id, customer])
  );
  customersToAdd.forEach(customer => {
    if (customer.external_id) merged.set(customer.external_id, customer);
  });
  selectedCustomers.value = Array.from(merged.values());
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
};

const saveGroup = async () => {
  if (!groupName.value || !hasSelectedResults.value) return;

  isSavingGroup.value = true;
  try {
    await messageBroadcastAPI.createGroup({
      name: groupName.value,
      members: selectedResultCustomers.value.map(customerToMemberPayload),
    });
    groupName.value = '';
    selectedResultIds.value = [];
    await fetchGroups();
    useAlert(t('IBSOFT_THEME.MESSAGE_BROADCAST.ALERTS.GROUP_CREATED'));
  } finally {
    isSavingGroup.value = false;
  }
};

const broadcastPayload = () => {
  const template = selectedTemplate.value;
  return {
    inbox_id: draftForm.value.inboxId,
    source_type: sourceMode.value === 'groups' ? 'group' : 'selection',
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
          }
        : {
            type: 'customer_field',
            field: row.field,
            component_type: row.component_type,
            button_type: row.button_type,
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
  [template.name, template.language, template.status]
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

const buildVariableRows = template => {
  variableRows.value = (template?.variables || []).map(variable => ({
    key: variable.key,
    label: variable.label,
    component_type: variable.component_type,
    button_type: variable.button_type,
    type: 'customer_field',
    field: 'name',
    value: '',
  }));
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
  if (status === 'sent') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.SENT');
  }
  if (status === 'skipped') {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.SKIPPED');
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.STATUS.DRAFT');
};

const customerAddressLabel = customer =>
  [customer.address, customer.neighborhood].filter(Boolean).join(' · ');

const customerLocationLabel = customer =>
  [customer.city_name, customer.state, customer.search_context]
    .filter(Boolean)
    .join(' · ');

const goToResultPage = page => {
  if (page < 1) return;
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
      class="mx-auto flex w-full max-w-5xl flex-col gap-5 px-6 py-6"
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
          class="rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
        >
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
          <div v-else class="divide-y divide-n-weak">
            <article
              v-for="broadcast in broadcasts"
              :key="broadcast.id"
              class="grid cursor-pointer gap-3 px-4 py-3 transition-colors hover:bg-n-alpha-1 md:grid-cols-[minmax(0,1fr),auto,auto,auto] md:items-center"
              role="button"
              tabindex="0"
              @click="openBroadcast(broadcast)"
              @keydown.enter.prevent="openBroadcast(broadcast)"
            >
              <div class="min-w-0">
                <p class="truncate font-medium text-n-slate-12">
                  {{ broadcast.template_name }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{ formatDate(broadcast.created_at) }}
                </p>
              </div>
              <span class="text-sm text-n-slate-11">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.RECIPIENTS', {
                    count: broadcast.recipients_count,
                  })
                }}
              </span>
              <span
                class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs text-n-slate-11"
              >
                {{ statusLabel(broadcast.status) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.ID', {
                    id: broadcast.id,
                  })
                }}
              </span>
            </article>
          </div>
        </section>
      </template>

      <template v-else-if="currentView === 'detail'">
        <section class="flex flex-wrap items-center justify-between gap-3">
          <Button
            variant="ghost"
            icon="i-lucide-arrow-left"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK_TO_HISTORY')"
            @click="backToHistory"
          />
          <Button
            icon="i-lucide-send"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEND_NOW')"
            :disabled="!canSendSelectedBroadcast"
            :is-loading="isSendingBroadcast"
            @click="sendSelectedBroadcast"
          />
        </section>

        <div
          v-if="isLoadingBroadcastDetail"
          class="flex min-h-64 items-center justify-center"
        >
          <Spinner />
        </div>

        <section
          v-else-if="selectedBroadcast"
          class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_360px]"
        >
          <div class="rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak">
            <div class="border-b border-n-weak px-4 py-3">
              <h2 class="font-semibold text-n-slate-12">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.TITLE', {
                    id: selectedBroadcast.id,
                  })
                }}
              </h2>
              <p class="text-sm text-n-slate-11">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.TEMPLATE_META', {
                    name: selectedBroadcast.template_name,
                    language: selectedBroadcast.template_language,
                  })
                }}
              </p>
            </div>

            <div class="divide-y divide-n-weak">
              <article
                v-for="recipient in selectedBroadcastRecipients"
                :key="recipient.id"
                class="grid gap-3 px-4 py-3 md:grid-cols-[minmax(0,1fr),auto,auto]"
              >
                <div class="min-w-0">
                  <p class="truncate font-medium text-n-slate-12">
                    {{ recipient.customer_name }}
                  </p>
                  <p class="truncate text-xs text-n-slate-11">
                    {{
                      recipient.phone_used ||
                      recipient.primary_phone ||
                      recipient.fallback_phone ||
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.NO_PHONE')
                    }}
                  </p>
                  <p
                    v-if="recipient.error_message"
                    class="mt-1 truncate text-xs text-n-ruby-9"
                  >
                    {{ recipient.error_message }}
                  </p>
                </div>
                <span
                  class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs text-n-slate-11"
                >
                  {{ statusLabel(recipient.status) }}
                </span>
                <RouterLink
                  v-if="recipient.conversation_display_id"
                  class="text-xs font-medium text-n-brand"
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
              </article>
            </div>
          </div>

          <aside class="grid content-start gap-4">
            <section
              class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
            >
              <h2 class="font-medium text-n-slate-12">
                {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.SUMMARY') }}
              </h2>
              <dl class="mt-4 grid gap-3 text-sm">
                <div class="flex justify-between gap-3">
                  <dt class="text-n-slate-11">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.STATUS') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ statusLabel(selectedBroadcast.status) }}
                  </dd>
                </div>
                <div class="flex justify-between gap-3">
                  <dt class="text-n-slate-11">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.TITLE') }}
                  </dt>
                  <dd class="font-medium text-n-slate-12">
                    {{ selectedBroadcast.recipients_count }}
                  </dd>
                </div>
                <div class="flex justify-between gap-3">
                  <dt class="text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CONVERSATION_MODE'
                      )
                    }}
                  </dt>
                  <dd class="text-right font-medium text-n-slate-12">
                    {{
                      selectedBroadcast.conversation_mode === 'keep_open'
                        ? t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.KEEP_OPEN')
                        : t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CLOSE_AFTER_SEND'
                          )
                    }}
                  </dd>
                </div>
                <div class="flex justify-between gap-3">
                  <dt class="text-n-slate-11">
                    {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.DETAIL.CREATED_AT') }}
                  </dt>
                  <dd class="text-right font-medium text-n-slate-12">
                    {{ formatDate(selectedBroadcast.created_at) }}
                  </dd>
                </div>
              </dl>
            </section>
          </aside>
        </section>
      </template>

      <template v-else>
        <section class="flex flex-wrap items-center justify-between gap-3">
          <Button
            variant="ghost"
            icon="i-lucide-arrow-left"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK_TO_HISTORY')"
            @click="backToHistory"
          />
          <nav class="flex flex-wrap gap-2">
            <span
              v-for="step in stepItems"
              :key="step.id"
              class="rounded-full px-3 py-1 text-xs font-medium"
              :class="
                builderStep === step.id
                  ? 'bg-n-brand text-n-solid-1'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              {{ step.label }}
            </span>
          </nav>
        </section>

        <section
          v-if="builderStep === 'source'"
          class="grid gap-4 md:grid-cols-2"
        >
          <button
            v-for="option in sourceOptions"
            :key="option.id"
            type="button"
            class="rounded-xl bg-n-alpha-1 p-5 text-left outline outline-1 outline-n-weak transition-colors hover:outline-n-brand"
            @click="chooseSource(option.id)"
          >
            <span :class="option.icon" class="mb-4 block size-6 text-n-brand" />
            <span class="block text-lg font-semibold text-n-slate-12">
              {{ option.title }}
            </span>
            <span class="mt-2 block text-sm text-n-slate-11">
              {{ option.description }}
            </span>
          </button>
        </section>

        <template v-if="builderStep === 'recipients'">
          <section
            data-testid="message-broadcast-recipient-step"
            class="flex min-w-0 flex-col gap-4"
          >
            <div class="flex min-w-0 flex-col gap-4">
              <section
                v-if="sourceMode === 'groups'"
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
                  <Button
                    variant="secondary"
                    icon="i-lucide-plus"
                    :label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.ADD_GROUPS')
                    "
                    :disabled="selectedGroupIds.length === 0"
                    @click="addSelectedGroupsToRecipients"
                  />
                </div>
                <div class="mt-4 grid gap-2 md:grid-cols-2">
                  <button
                    v-for="group in groups"
                    :key="group.id"
                    type="button"
                    class="rounded-lg p-3 text-left outline outline-1 transition-colors"
                    :class="
                      selectedGroupIds.includes(String(group.id))
                        ? 'bg-n-alpha-2 outline-n-brand'
                        : 'bg-n-alpha-1 outline-n-weak'
                    "
                    @click="toggleGroup(group)"
                  >
                    <span class="block font-medium text-n-slate-12">
                      {{ group.name }}
                    </span>
                    <span class="text-xs text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.MEMBERS', {
                          count: group.members_count,
                        })
                      }}
                    </span>
                  </button>
                </div>
              </section>

              <section
                class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 class="font-semibold text-n-slate-12">
                      {{
                        sourceMode === 'groups'
                          ? t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.CREATE_FROM_FILTERS'
                            )
                          : t('IBSOFT_THEME.MESSAGE_BROADCAST.SEARCH.TITLE')
                      }}
                    </h2>
                    <p class="text-sm text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.SEARCH.DESCRIPTION')
                      }}
                    </p>
                  </div>
                </div>

                <SearchModeMenu
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
                        class="ibsoft-broadcast-input"
                      />
                    </label>
                    <label
                      class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                    >
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STATE') }}
                      <LookupSingleSelect
                        v-model="directFilters.stateId"
                        v-model:query="stateQuery"
                        :options="stateOptions"
                        :placeholder="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_STATE')
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
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
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STREET') }}
                      <input
                        v-model="directFilters.street"
                        class="ibsoft-broadcast-input"
                      />
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.NEIGHBORHOOD')
                      }}
                      <input
                        v-model="directFilters.neighborhood"
                        class="ibsoft-broadcast-input"
                      />
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ZIP_CODE') }}
                      <input
                        v-model="directFilters.zipCode"
                        class="ibsoft-broadcast-input"
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
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.STATE') }}
                      <LookupSingleSelect
                        v-model="contractFilters.stateId"
                        v-model:query="stateQuery"
                        :options="stateOptions"
                        :placeholder="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ANY_STATE')
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
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
                      <IbsoftSelect v-model="contractFilters.contractStatus">
                        <option
                          v-for="option in contractStatusOptions"
                          :key="option.value"
                          :value="option.value"
                        >
                          {{ option.label }}
                        </option>
                      </IbsoftSelect>
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.INTERNET_STATUS'
                        )
                      }}
                      <IbsoftSelect v-model="contractFilters.internetStatus">
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED', {
                            count: contractFilters.selectedPlanIds.length,
                          })
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
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
                      <IbsoftSelect v-model="concentratorFilters.clientActive">
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
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.CONCENTRATOR')
                      }}
                      <input
                        v-model="concentratorFilters.concentratorIds"
                        class="ibsoft-broadcast-input"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                          )
                        "
                      />
                    </label>
                    <label
                      class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                    >
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.POP_IDS') }}
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED', {
                            count: concentratorFilters.selectedPopIds.length,
                          })
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
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
                        "
                      />
                    </label>
                    <label
                      class="grid min-w-0 w-full gap-1 text-sm text-n-slate-11"
                    >
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMITTER')
                      }}
                      <LookupMultiSelect
                        v-model="concentratorFilters.selectedTransmitterIds"
                        v-model:query="concentratorFilters.transmitterQuery"
                        :options="transmitterOptions"
                        :loading="isLoadingTransmitters"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.TRANSMITTERS_PLACEHOLDER'
                          )
                        "
                        :selected-label="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.SELECTED', {
                            count:
                              concentratorFilters.selectedTransmitterIds.length,
                          })
                        "
                        :search-placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.TRANSMITTERS_SEARCH'
                          )
                        "
                        :empty-state="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.EMPTY')
                        "
                        :loading-label="
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.LOADING')
                        "
                      />
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMISSION_INTERFACE'
                        )
                      }}
                      <input
                        v-model="concentratorFilters.transmissionInterfaceIds"
                        class="ibsoft-broadcast-input"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                          )
                        "
                      />
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.FTTH_BOX') }}
                      <input
                        v-model="concentratorFilters.ftthBoxIds"
                        class="ibsoft-broadcast-input"
                        :placeholder="
                          t(
                            'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.ID_LIST_PLACEHOLDER'
                          )
                        "
                      />
                    </label>
                    <label class="grid gap-1 text-sm text-n-slate-11">
                      {{
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.FILTERS.TRANSMITTER_PORT'
                        )
                      }}
                      <input
                        v-model="concentratorFilters.transmitterPortIds"
                        class="ibsoft-broadcast-input"
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
                    :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEARCH')"
                    icon="i-lucide-search"
                    :is-loading="isSearching"
                    @click="runFilteredCustomerSearch"
                  />
                </div>
              </section>

              <section
                class="rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
              >
                <div
                  class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-4 py-3"
                >
                  <div>
                    <h2 class="font-medium text-n-slate-12">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.TITLE') }}
                    </h2>
                    <p class="text-xs text-n-slate-11">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.PAGE_INFO', {
                          page: resultPage,
                          count: customers.length,
                        })
                      }}
                    </p>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <PageSizeSelect
                      :model-value="resultPerPage"
                      :default-value="DEFAULT_PER_PAGE"
                      @update:model-value="changeResultPerPage"
                    />
                    <Button
                      variant="secondary"
                      :label="
                        isCurrentPageSelected
                          ? t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.UNSELECT_PAGE'
                            )
                          : t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SELECT_PAGE'
                            )
                      "
                      :disabled="customers.length === 0"
                      @click="toggleCurrentPageSelection"
                    />
                    <Button
                      v-if="sourceMode === 'search'"
                      icon="i-lucide-user-plus"
                      :label="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.ADD_SELECTED')
                      "
                      :disabled="!hasSelectedResults"
                      @click="addSelectedResultsToRecipients"
                    />
                    <Button
                      v-if="sourceMode === 'search'"
                      variant="secondary"
                      icon="i-lucide-users-round"
                      :label="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.ADD_ALL_RESULTS'
                        )
                      "
                      :disabled="resultMeta.total === 0"
                      :is-loading="isAddingAllResults"
                      @click="addAllResultsToRecipients"
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
                      class="ibsoft-broadcast-input !px-10"
                      :placeholder="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SEARCH_PLACEHOLDER'
                        )
                      "
                      :aria-label="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SEARCH_LABEL')
                      "
                      @input="scheduleFoundCustomersSearch"
                    />
                    <button
                      v-if="foundCustomersQuery"
                      type="button"
                      class="absolute right-3 top-1/2 z-10 flex size-5 -translate-y-1/2 items-center justify-center rounded text-n-slate-10 hover:text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                      :title="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.CLEAR_SEARCH')
                      "
                      :aria-label="
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.CLEAR_SEARCH')
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
                      type="checkbox"
                      class="size-4"
                      :checked="isCustomerSelected(customer)"
                      @click.stop="toggleCustomer(customer)"
                    />
                    <span class="min-w-0">
                      <span class="block truncate font-medium text-n-slate-12">
                        {{ customer.name }}
                      </span>
                      <span class="block truncate text-xs text-n-slate-11">
                        {{ customerAddressLabel(customer) }}
                      </span>
                      <span class="block truncate text-xs text-n-slate-10">
                        {{ customerLocationLabel(customer) }}
                      </span>
                    </span>
                    <span class="text-right text-xs text-n-slate-11">
                      {{
                        customer.phone_selection?.primary_phone ||
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.NO_PHONE')
                      }}
                    </span>
                  </button>
                </div>

                <div
                  v-if="customers.length"
                  class="border-t border-n-weak px-4 py-3 text-center"
                >
                  <span class="text-xs text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.SELECTED_ON_PAGE',
                        {
                          count: selectedResultIds.length,
                        }
                      )
                    }}
                  </span>
                </div>
                <PaginationFooter
                  v-if="resultMeta.total > DEFAULT_PER_PAGE"
                  class="[&_.bg-n-input-background]:!bg-n-alpha-3 [&_.bg-n-input-background]:!text-n-slate-12 [&_.bg-n-input-background]:outline [&_.bg-n-input-background]:outline-1 [&_.bg-n-input-background]:outline-n-weak"
                  :current-page="resultPage"
                  :total-items="resultMeta.total"
                  :items-per-page="resultMeta.per_page"
                  current-page-info="IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.PAGINATION"
                  @update:current-page="goToResultPage"
                />
              </section>
            </div>

            <div class="flex min-w-0 flex-col gap-4">
              <section
                v-if="sourceMode === 'groups'"
                class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <h2 class="font-medium text-n-slate-12">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.SAVE_TITLE') }}
                </h2>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.SAVE_DESCRIPTION')
                  }}
                </p>
                <div class="mt-3 grid gap-2">
                  <input v-model="groupName" class="ibsoft-broadcast-input" />
                  <Button
                    variant="secondary"
                    icon="i-lucide-save"
                    :label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SAVE_GROUP')
                    "
                    :disabled="!groupName || !hasSelectedResults"
                    :is-loading="isSavingGroup"
                    @click="saveGroup"
                  />
                </div>
              </section>

              <RecipientTable
                :recipients="selectedCustomers"
                :can-continue="canGoToReview"
                @continue="goToReview"
                @remove="removeRecipient"
                @update="updateRecipient"
              />
            </div>
          </section>
        </template>

        <template v-if="builderStep === 'review'">
          <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_420px]">
            <div
              class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
            >
              <h2 class="font-semibold text-n-slate-12">
                {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TITLE') }}
              </h2>
              <div class="mt-4 grid gap-3 md:grid-cols-2">
                <label class="grid gap-1 text-sm text-n-slate-11">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.INBOX') }}
                  <IbsoftSelect v-model="draftForm.inboxId">
                    <option value="">
                      {{
                        t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SELECT_INBOX')
                      }}
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
                <label class="grid gap-1 text-sm text-n-slate-11">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE') }}
                  <IbsoftSelect
                    v-model="draftForm.templateId"
                    :disabled="!draftForm.inboxId || isLoadingTemplates"
                  >
                    <option value="">
                      {{
                        isLoadingTemplates
                          ? t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_LOADING'
                            )
                          : t(
                              'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SELECT_TEMPLATE'
                            )
                      }}
                    </option>
                    <option
                      v-for="template in templateOptions"
                      :key="template.id"
                      :value="template.id"
                    >
                      {{ templateOptionLabel(template) }}
                    </option>
                  </IbsoftSelect>
                </label>
                <label class="grid gap-1 text-sm text-n-slate-11">
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.CONVERSATION_MODE')
                  }}
                  <IbsoftSelect v-model="draftForm.conversationMode">
                    <option
                      v-for="option in conversationModeOptions"
                      :key="option.value"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </IbsoftSelect>
                </label>
              </div>

              <div class="mt-6">
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <h3 class="font-medium text-n-slate-12">
                      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.TITLE') }}
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
                        {{ row.label }}
                      </span>
                      <span class="text-xs text-n-slate-10">
                        {{ templateVariableComponentLabel(row) }}
                      </span>
                    </div>
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
                    <input
                      v-else
                      :value="row.value"
                      class="ibsoft-broadcast-input"
                      :placeholder="
                        t(
                          'IBSOFT_THEME.MESSAGE_BROADCAST.VARIABLES.FIXED_PLACEHOLDER'
                        )
                      "
                      @input="updateFixedVariable(row, $event.target.value)"
                      @keydown.enter.prevent
                    />
                  </div>
                </div>
              </div>
            </div>

            <aside class="grid gap-4">
              <section
                class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <h2 class="font-medium text-n-slate-12">
                  {{
                    t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_PREVIEW')
                  }}
                </h2>
                <div
                  v-if="!selectedTemplate"
                  class="mt-4 text-sm text-n-slate-11"
                >
                  {{
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_PREVIEW_EMPTY'
                    )
                  }}
                </div>
                <div v-else class="mt-4 grid gap-4">
                  <div>
                    <h3 class="font-semibold text-n-slate-12">
                      {{ selectedTemplate.name }}
                    </h3>
                    <div class="mt-2 flex flex-wrap gap-2">
                      <span
                        class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-11"
                      >
                        {{ selectedTemplate.language }}
                      </span>
                      <span
                        v-if="selectedTemplate.status"
                        class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-11"
                      >
                        {{ selectedTemplate.status }}
                      </span>
                      <span
                        v-if="selectedTemplate.category"
                        class="rounded-full bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-11"
                      >
                        {{ selectedTemplate.category }}
                      </span>
                    </div>
                  </div>

                  <article
                    v-for="component in selectedTemplate.components"
                    :key="`${component.type}-${component.text || component.format || ''}`"
                    class="rounded-lg bg-n-alpha-1 p-3 outline outline-1 outline-n-weak"
                  >
                    <h4
                      class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                    >
                      {{ componentTypeLabel(component.type) }}
                    </h4>
                    <p
                      v-if="component.text"
                      class="mt-2 whitespace-pre-wrap text-sm leading-6 text-n-slate-12"
                    >
                      {{ component.text }}
                    </p>
                    <p
                      v-if="component.format"
                      class="mt-2 text-xs text-n-slate-11"
                    >
                      {{ component.format }}
                    </p>
                    <div
                      v-if="component.buttons?.length"
                      class="mt-3 grid gap-2"
                    >
                      <span
                        v-for="button in component.buttons"
                        :key="`${button.type}-${button.text}-${button.url}`"
                        class="rounded-md bg-n-alpha-2 px-3 py-2 text-xs text-n-slate-11"
                      >
                        {{
                          [button.text, button.type].filter(Boolean).join(' · ')
                        }}
                      </span>
                    </div>
                  </article>
                </div>
              </section>

              <section
                class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
              >
                <h2 class="font-medium text-n-slate-12">
                  {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SUMMARY') }}
                </h2>
                <dl class="mt-4 grid gap-3 text-sm">
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
                <div class="mt-5 grid gap-2">
                  <Button
                    variant="secondary"
                    icon="i-lucide-arrow-left"
                    :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.BACK')"
                    @click="builderStep = 'recipients'"
                  />
                  <Button
                    icon="i-lucide-send"
                    :label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.SEND_NOW')
                    "
                    :disabled="!canSendNewBroadcast || isSubmittingBroadcast"
                    :is-loading="isSendingBroadcastNow"
                    @click="sendBroadcastNow"
                  />
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
                </div>
              </section>
            </aside>
          </section>
        </template>
      </template>
    </section>
  </main>
</template>

<style scoped>
.ibsoft-broadcast-input {
  @apply !mb-0 box-border min-h-10 w-full rounded-lg border-0 bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-transparent transition-colors hover:outline-n-weak focus:outline-n-brand;
}
</style>
