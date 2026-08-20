<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import IntegrationInstructions from './IntegrationInstructions.vue';
import InstanceTypeMark from './InstanceTypeMark.vue';
import OrdersPanel from './OrdersPanel.vue';

const props = defineProps({
  endpoint: {
    type: Object,
    required: true,
  },
  typeDefinition: {
    type: Object,
    required: true,
  },
  deliveries: {
    type: Array,
    default: () => [],
  },
  deliveryMeta: {
    type: Object,
    required: true,
  },
  isFetchingDeliveries: {
    type: Boolean,
    default: false,
  },
  historyLoaded: {
    type: Boolean,
    default: false,
  },
  publicEndpointUrl: {
    type: String,
    required: true,
  },
  publicCurlExample: {
    type: String,
    required: true,
  },
  orderUpdateEndpointUrl: {
    type: String,
    default: '',
  },
  orderUpdateCurlExample: {
    type: String,
    default: '',
  },
  integrationParameters: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'back',
  'edit',
  'credentials',
  'toggle',
  'loadHistory',
  'configureOrders',
]);
const { t, locale } = useI18n();

const activeTab = ref('overview');
const statusFilter = ref('');
const historyPageSize = ref(props.deliveryMeta.per_page || 25);
const historyPageSizes = [10, 25, 50, 100];
const statuses = computed(() => [
  {
    value: 'queued',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.QUEUED'),
  },
  {
    value: 'processing',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.PROCESSING'),
  },
  {
    value: 'accepted',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.ACCEPTED'),
  },
  {
    value: 'sent',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.SENT'),
  },
  {
    value: 'delivered',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.DELIVERED'),
  },
  {
    value: 'read',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.READ'),
  },
  {
    value: 'failed',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.FAILED'),
  },
  {
    value: 'uncertain',
    label: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.UNCERTAIN'),
  },
]);

const tabs = computed(() => {
  const items = [
    {
      id: 'overview',
      icon: 'i-lucide-layout-dashboard',
      label: t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TABS.OVERVIEW'),
    },
    {
      id: 'instructions',
      icon: 'i-lucide-book-open',
      label: t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TABS.INSTRUCTIONS'),
    },
    {
      id: 'history',
      icon: 'i-lucide-history',
      label: t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TABS.HISTORY'),
    },
  ];

  items.splice(1, 0, {
    id: 'orders',
    icon: 'i-lucide-receipt-text',
    label: t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TABS.ORDERS'),
  });

  return items;
});
const totalPages = computed(() =>
  Math.max(1, Math.ceil(props.deliveryMeta.total / historyPageSize.value))
);
const dateTimeLocale = computed(() =>
  String(locale.value || 'pt-BR').replace(/_/g, '-')
);

const loadHistory = (page = 1) => {
  emit('loadHistory', {
    status: statusFilter.value,
    page,
    per_page: historyPageSize.value,
  });
};

const selectTab = tabId => {
  activeTab.value = tabId;
  if (tabId === 'history' && !props.historyLoaded) loadHistory();
};

const applyHistoryFilter = () => loadHistory(1);
const changeHistoryPageSize = () => loadHistory(1);
const changePage = page =>
  loadHistory(Math.min(Math.max(page, 1), totalPages.value));

const statusLabel = status =>
  statuses.value.find(option => option.value === status)?.label ||
  t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE');

const showFailureDiagnostics = computed(
  () => props.endpoint.failure_diagnostics_enabled === true
);

const deliveryDiagnostic = delivery => {
  if (!delivery.error_code && !delivery.error_message) {
    return t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE');
  }

  const parts = [];
  if (delivery.error_code) {
    parts.push(
      t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.ERROR_CODE', {
        code: delivery.error_code,
      })
    );
  }
  if (delivery.meta_http_status) {
    parts.push(
      t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.HTTP_STATUS', {
        status: delivery.meta_http_status,
      })
    );
  }
  if (delivery.error_message) parts.push(delivery.error_message);

  return (
    parts.join(' · ') || t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE')
  );
};

const formatDate = value => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE');
  }

  try {
    return new Intl.DateTimeFormat(dateTimeLocale.value, {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(date);
  } catch {
    return new Intl.DateTimeFormat('pt-BR', {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(date);
  }
};

watch(
  () => props.deliveryMeta.per_page,
  perPage => {
    historyPageSize.value = perPage || 25;
  }
);

watch(
  () => props.endpoint.id,
  () => {
    activeTab.value = 'overview';
    statusFilter.value = '';
  }
);
</script>

<template>
  <div class="grid min-w-0 gap-5">
    <header class="flex flex-col gap-4">
      <Button
        :label="t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.BACK')"
        icon="i-lucide-arrow-left"
        color="slate"
        variant="link"
        class="w-fit"
        @click="emit('back')"
      />

      <div
        class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between"
      >
        <div class="flex min-w-0 items-start gap-3">
          <span
            class="grid h-11 w-24 shrink-0 place-content-center rounded-lg bg-n-alpha-2 px-2 text-n-slate-12"
          >
            <InstanceTypeMark
              :type-definition="typeDefinition"
              image-class="max-h-7 max-w-20"
            />
          </span>
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="mb-0 truncate text-heading-1 text-n-slate-12">
                {{ endpoint.name }}
              </h1>
              <span
                class="rounded-md px-2 py-1 text-label-small"
                :class="
                  endpoint.active
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-alpha-2 text-n-slate-11'
                "
              >
                {{
                  endpoint.active
                    ? t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVE')
                    : t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.INACTIVE')
                }}
              </span>
            </div>
            <p class="mb-0 mt-1 text-body-small text-n-slate-11">
              {{
                t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TYPE_AND_CHANNEL', {
                  type: typeDefinition.label,
                  channel: endpoint.inbox_name,
                })
              }}
            </p>
          </div>
        </div>

        <div class="flex shrink-0 items-center gap-1">
          <Button
            v-tooltip.top="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EDIT')"
            icon="i-lucide-pencil"
            size="sm"
            color="slate"
            variant="ghost"
            :aria-label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EDIT')"
            @click="emit('edit', endpoint)"
          />
          <Button
            v-tooltip.top="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREDENTIALS')"
            icon="i-lucide-key-round"
            size="sm"
            color="slate"
            variant="ghost"
            :aria-label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREDENTIALS')"
            @click="emit('credentials', endpoint)"
          />
          <Button
            v-tooltip.top="
              endpoint.active
                ? t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.DEACTIVATE')
                : t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVATE')
            "
            :icon="
              endpoint.active ? 'i-lucide-circle-pause' : 'i-lucide-circle-play'
            "
            size="sm"
            :color="endpoint.active ? 'ruby' : 'teal'"
            variant="ghost"
            :aria-label="
              endpoint.active
                ? t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.DEACTIVATE')
                : t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVATE')
            "
            @click="emit('toggle', endpoint)"
          />
        </div>
      </div>
    </header>

    <nav
      class="grid grid-cols-2 gap-1 rounded-lg bg-n-alpha-2 p-1 md:grid-cols-4"
      :aria-label="t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.TABS.LABEL')"
    >
      <button
        v-for="tab in tabs"
        :key="tab.id"
        type="button"
        class="flex min-h-10 min-w-0 items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
        :class="
          activeTab === tab.id
            ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
            : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12'
        "
        @click="selectTab(tab.id)"
      >
        <i class="size-4 shrink-0" :class="tab.icon" />
        <span class="truncate">{{ tab.label }}</span>
      </button>
    </nav>

    <section
      v-if="activeTab === 'overview'"
      class="rounded-lg border border-n-weak"
    >
      <div class="border-b border-n-weak p-4">
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.OVERVIEW.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ typeDefinition.description }}
        </p>
      </div>

      <dl class="grid md:grid-cols-2">
        <div class="border-b border-n-weak p-4 md:border-r">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CHANNEL') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{ endpoint.inbox_name }}
          </dd>
        </div>
        <div class="border-b border-n-weak p-4">
          <template
            v-if="endpoint.authentication?.type === 'username_password'"
          >
            <dt class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.USERNAME') }}
            </dt>
            <dd class="mt-1 font-mono text-sm text-n-slate-12">
              {{ endpoint.authentication.username }}
            </dd>
            <dt class="mt-2 text-label-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.PASSWORD_HINT') }}
            </dt>
            <dd class="mt-1 font-mono text-sm text-n-slate-12">
              {{ endpoint.authentication.secret_hint }}
            </dd>
          </template>
          <template v-else>
            <dt class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.DETAIL.OVERVIEW.TOKEN') }}
            </dt>
            <dd class="mt-1 font-mono text-sm text-n-slate-12">
              {{ endpoint.token_hint }}
            </dd>
          </template>
        </div>
        <div class="border-b border-n-weak p-4 md:border-b-0 md:border-r">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RATE') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RATE_VALUE', {
                count: endpoint.rate_limit_per_second,
              })
            }}
          </dd>
        </div>
        <div class="p-4">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.REQUESTS') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{ endpoint.deliveries_count }}
          </dd>
        </div>
      </dl>
    </section>

    <OrdersPanel
      v-else-if="activeTab === 'orders'"
      :endpoint="endpoint"
      @configure-orders="emit('configureOrders', endpoint)"
    />

    <IntegrationInstructions
      v-else-if="activeTab === 'instructions'"
      :public-endpoint-url="publicEndpointUrl"
      :public-curl-example="publicCurlExample"
      :order-update-endpoint-url="orderUpdateEndpointUrl"
      :order-update-curl-example="orderUpdateCurlExample"
      :integration-parameters="integrationParameters"
      :instance-type="endpoint.instance_type"
      :authentication="endpoint.authentication"
    />

    <section v-else class="rounded-lg border border-n-weak">
      <div class="flex flex-col gap-3 border-b border-n-weak p-4">
        <div>
          <h2 class="mb-1 text-heading-2 text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.TITLE') }}
          </h2>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.DESCRIPTION') }}
          </p>
        </div>
        <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
          <IbsoftSelect v-model="statusFilter" class="w-full min-w-0 sm:w-64">
            <option value="">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.ALL_STATUSES') }}
            </option>
            <option
              v-for="status in statuses"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </IbsoftSelect>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.FILTER')"
            icon="i-lucide-filter"
            color="slate"
            variant="faded"
            class="shrink-0"
            @click="applyHistoryFilter"
          />
        </div>
      </div>

      <div
        v-if="isFetchingDeliveries"
        class="grid min-h-48 place-content-center"
      >
        <Spinner />
      </div>
      <div v-else-if="deliveries.length" class="overflow-x-auto">
        <table
          class="w-full border-collapse text-left"
          :class="showFailureDiagnostics ? 'min-w-[1040px]' : 'min-w-[760px]'"
        >
          <thead>
            <tr class="border-b border-n-weak text-label-small text-n-slate-11">
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.DATE') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.RECIPIENT') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.TEMPLATE') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.STATUS') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.META_ID') }}
              </th>
              <th v-if="showFailureDiagnostics" class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.DIAGNOSTIC') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="delivery in deliveries"
              :key="delivery.id"
              class="border-b border-n-weak last:border-b-0"
            >
              <td
                class="whitespace-nowrap px-4 py-3 text-body-small text-n-slate-11"
              >
                {{ formatDate(delivery.received_at) }}
              </td>
              <td class="px-4 py-3 font-mono text-body-small text-n-slate-12">
                {{ delivery.recipient }}
              </td>
              <td
                class="max-w-56 truncate px-4 py-3 text-body-small text-n-slate-12"
              >
                {{ delivery.template_name }}
              </td>
              <td class="px-4 py-3">
                <span
                  class="rounded-md bg-n-alpha-2 px-2 py-1 text-label-small text-n-slate-11"
                >
                  {{ statusLabel(delivery.status) }}
                </span>
              </td>
              <td
                class="max-w-64 truncate px-4 py-3 font-mono text-label-small text-n-slate-11"
              >
                {{
                  delivery.meta_message_id ||
                  t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE')
                }}
              </td>
              <td
                v-if="showFailureDiagnostics"
                class="max-w-80 px-4 py-3 text-label-small text-n-slate-11"
              >
                <span
                  class="block max-w-80 truncate"
                  data-testid="delivery-diagnostic"
                  :title="deliveryDiagnostic(delivery)"
                >
                  {{ deliveryDiagnostic(delivery) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div
          class="flex flex-col gap-3 border-t border-n-weak p-4 sm:flex-row sm:items-center sm:justify-between"
        >
          <label
            class="flex items-center gap-2 text-label-small text-n-slate-11"
          >
            {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.PER_PAGE') }}
            <IbsoftSelect
              v-model.number="historyPageSize"
              class="w-24"
              @change="changeHistoryPageSize"
            >
              <option
                v-for="size in historyPageSizes"
                :key="size"
                :value="size"
              >
                {{ size }}
              </option>
            </IbsoftSelect>
          </label>
          <div class="flex items-center justify-between gap-3 sm:justify-end">
            <Button
              :label="t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.PREVIOUS')"
              icon="i-lucide-chevron-left"
              size="sm"
              color="slate"
              variant="faded"
              :disabled="deliveryMeta.page <= 1"
              @click="changePage(deliveryMeta.page - 1)"
            />
            <span class="whitespace-nowrap text-label-small text-n-slate-11">
              {{
                t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.PAGE', {
                  page: deliveryMeta.page,
                  total: totalPages,
                })
              }}
            </span>
            <Button
              :label="t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NEXT')"
              icon="i-lucide-chevron-right"
              trailing-icon
              size="sm"
              color="slate"
              variant="faded"
              :disabled="deliveryMeta.page >= totalPages"
              @click="changePage(deliveryMeta.page + 1)"
            />
          </div>
        </div>
      </div>
      <div
        v-else
        class="grid min-h-48 place-content-center p-6 text-center text-n-slate-11"
      >
        {{ t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.EMPTY') }}
      </div>
    </section>
  </div>
</template>
