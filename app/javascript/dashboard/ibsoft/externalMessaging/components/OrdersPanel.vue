<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import externalMessagingAPI from '../api';
import BulkOrderUpdateDialog from './BulkOrderUpdateDialog.vue';

const props = defineProps({
  endpoint: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['configureOrders']);
const { t, locale } = useI18n();
const orders = ref([]);
const meta = ref({
  page: 1,
  per_page: 25,
  total: 0,
  updateable_total: 0,
});
const isLoading = ref(false);
const isUpdating = ref(false);
const selectedIds = ref(new Set());
const allFilteredSelected = ref(false);
const updateDialogRef = ref(null);
const filters = reactive({
  recipient: '',
  reference_id: '',
  order_status: '',
  payment_status: '',
  date_from: '',
  date_to: '',
});
const appliedFilters = ref({});

const orderStatusOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.ALL_ORDER_STATUSES'),
  },
  {
    value: 'pending',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.PENDING'),
  },
  {
    value: 'processing',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.PROCESSING'),
  },
  {
    value: 'partially_shipped',
    label: t(
      'IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.PARTIALLY_SHIPPED'
    ),
  },
  {
    value: 'shipped',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.SHIPPED'),
  },
  {
    value: 'completed',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.COMPLETED'),
  },
  {
    value: 'canceled',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.ORDER_STATUSES.CANCELED'),
  },
]);
const paymentStatusOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.ALL_PAYMENT_STATUSES'),
  },
  {
    value: 'pending',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PAYMENT_STATUSES.PENDING'),
  },
  {
    value: 'captured',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PAYMENT_STATUSES.CAPTURED'),
  },
  {
    value: 'failed',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PAYMENT_STATUSES.FAILED'),
  },
]);
const updateStatusLabels = computed(() => ({
  queued: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.QUEUED'),
  processing: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.PROCESSING'),
  accepted: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.ACCEPTED'),
  sent: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.SENT'),
  delivered: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.DELIVERED'),
  read: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.READ'),
  failed: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.FAILED'),
  uncertain: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.UNCERTAIN'),
  unchanged: t('IBSOFT_EXTERNAL_MESSAGING.STATUSES.UNCHANGED'),
}));
const pageSizes = [10, 25, 50, 100];
const selectableOrders = computed(() =>
  orders.value.filter(order => order.manually_updateable)
);
const allPageSelected = computed(
  () =>
    selectableOrders.value.length > 0 &&
    selectableOrders.value.every(order => selectedIds.value.has(order.id))
);
const selectedCount = computed(() =>
  allFilteredSelected.value
    ? meta.value.updateable_total
    : selectedIds.value.size
);
const totalPages = computed(() =>
  Math.max(1, Math.ceil(meta.value.total / meta.value.per_page))
);
const dateTimeLocale = computed(() =>
  String(locale.value || 'pt-BR').replace(/_/g, '-')
);

const normalizedFilters = () =>
  Object.fromEntries(
    Object.entries(filters).filter(([, value]) => String(value).trim())
  );

const resetSelection = () => {
  selectedIds.value = new Set();
  allFilteredSelected.value = false;
};

const fetchOrders = async (page = 1) => {
  isLoading.value = true;
  try {
    const { data } = await externalMessagingAPI.getOrders({
      endpoint_id: props.endpoint.id,
      page,
      per_page: meta.value.per_page,
      ...appliedFilters.value,
    });
    orders.value = data.orders || [];
    meta.value = { ...meta.value, ...data.meta };
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.ORDERS_LOAD'));
  } finally {
    isLoading.value = false;
  }
};

const applyFilters = () => {
  appliedFilters.value = normalizedFilters();
  resetSelection();
  fetchOrders(1);
};

const clearFilters = () => {
  Object.keys(filters).forEach(key => {
    filters[key] = '';
  });
  appliedFilters.value = {};
  resetSelection();
  fetchOrders(1);
};

const setSelectedIds = ids => {
  selectedIds.value = new Set(ids);
};

const toggleOrder = order => {
  if (!order.manually_updateable || allFilteredSelected.value) return;

  const next = new Set(selectedIds.value);
  if (next.has(order.id)) {
    next.delete(order.id);
  } else {
    next.add(order.id);
  }
  selectedIds.value = next;
};

const togglePage = () => {
  if (allFilteredSelected.value) return;

  const next = new Set(selectedIds.value);
  selectableOrders.value.forEach(order => {
    if (allPageSelected.value) {
      next.delete(order.id);
    } else {
      next.add(order.id);
    }
  });
  selectedIds.value = next;
};

const selectAllFiltered = () => {
  allFilteredSelected.value = true;
  setSelectedIds([]);
};

const openBulkUpdate = () =>
  updateDialogRef.value?.open({
    count: selectedCount.value,
    allFiltered: allFilteredSelected.value,
  });

const submitBulkUpdate = async update => {
  isUpdating.value = true;
  try {
    const selection = allFilteredSelected.value
      ? { mode: 'filter' }
      : { mode: 'ids', ids: Array.from(selectedIds.value) };
    const { data } = await externalMessagingAPI.bulkUpdateOrders({
      endpoint_id: props.endpoint.id,
      selection,
      filters: appliedFilters.value,
      update,
    });
    updateDialogRef.value?.close();
    resetSelection();
    useAlert(
      t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.ACCEPTED', {
        count: data.count,
      })
    );
    await fetchOrders(meta.value.page);
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.ORDERS_UPDATE'));
  } finally {
    isUpdating.value = false;
  }
};

const changePage = page => {
  resetSelection();
  fetchOrders(Math.min(Math.max(page, 1), totalPages.value));
};

const changePageSize = () => {
  resetSelection();
  fetchOrders(1);
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

const orderStatusLabel = status =>
  orderStatusOptions.value.find(option => option.value === status)?.label ||
  t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE');
const paymentStatusLabel = status =>
  paymentStatusOptions.value.find(option => option.value === status)?.label ||
  t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PAYMENT_STATUSES.NOT_INFORMED');
const updateStatusLabel = status =>
  updateStatusLabels.value[status] ||
  t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.NOT_AVAILABLE');

watch(
  () => props.endpoint.id,
  () => {
    clearFilters();
  }
);

onMounted(() => fetchOrders());
</script>

<template>
  <div class="grid min-w-0 gap-5">
    <section class="rounded-lg border border-n-weak">
      <div
        class="flex flex-col gap-3 border-b border-n-weak p-4 sm:flex-row sm:items-start sm:justify-between"
      >
        <div>
          <h2 class="mb-1 text-heading-2 text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.CONFIGURATION_TITLE') }}
          </h2>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.DESCRIPTION') }}
          </p>
        </div>
        <Button
          :label="
            endpoint.order_defaults_configured
              ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.EDIT')
              : t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.CONFIGURE')
          "
          icon="i-lucide-settings-2"
          color="slate"
          variant="faded"
          class="shrink-0"
          @click="emit('configureOrders', endpoint)"
        />
      </div>

      <dl class="grid sm:grid-cols-2 lg:grid-cols-4">
        <div class="border-b border-n-weak p-4 lg:border-b-0 lg:border-r">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MERCHANT_NAME') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{
              endpoint.order_defaults?.merchant_name ||
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.NOT_CONFIGURED')
            }}
          </dd>
        </div>
        <div class="border-b border-n-weak p-4 sm:border-l lg:border-b-0">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.KEY_TYPE') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{
              endpoint.order_defaults?.key_type ||
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.NOT_CONFIGURED')
            }}
          </dd>
        </div>
        <div class="border-b border-n-weak p-4 lg:border-b-0 lg:border-l">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PIX_KEY') }}
          </dt>
          <dd class="mt-1 font-mono text-sm text-n-slate-12">
            {{
              endpoint.order_defaults?.key_hint ||
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.NOT_CONFIGURED')
            }}
          </dd>
        </div>
        <div class="p-4 sm:border-l">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.RETENTION.TITLE') }}
          </dt>
          <dd class="mt-1 text-sm text-n-slate-12">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.RETENTION.VALUE', {
                count: endpoint.retention_days,
              })
            }}
          </dd>
        </div>
      </dl>
    </section>

    <section class="rounded-lg border border-n-weak">
      <header class="border-b border-n-weak p-4">
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.LIST.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.LIST.DESCRIPTION') }}
        </p>
      </header>

      <form
        class="grid gap-3 border-b border-n-weak p-4 md:grid-cols-2 xl:grid-cols-3"
        @submit.prevent="applyFilters"
      >
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.RECIPIENT') }}
          </span>
          <input
            v-model="filters.recipient"
            type="search"
            class="!mb-0 h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.REFERENCE') }}
          </span>
          <input
            v-model="filters.reference_id"
            type="search"
            class="!mb-0 h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.ORDER_STATUS') }}
          </span>
          <IbsoftSelect
            v-model="filters.order_status"
            class="h-10 [&>select]:!h-10 [&>select]:!bg-n-solid-1"
          >
            <option
              v-for="status in orderStatusOptions"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </IbsoftSelect>
        </label>
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.PAYMENT_STATUS') }}
          </span>
          <IbsoftSelect
            v-model="filters.payment_status"
            class="h-10 [&>select]:!h-10 [&>select]:!bg-n-solid-1"
          >
            <option
              v-for="status in paymentStatusOptions"
              :key="status.value"
              :value="status.value"
            >
              {{ status.label }}
            </option>
          </IbsoftSelect>
        </label>
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.DATE_FROM') }}
          </span>
          <input
            v-model="filters.date_from"
            type="date"
            class="!mb-0 h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>
        <label class="grid content-start gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.DATE_TO') }}
          </span>
          <input
            v-model="filters.date_to"
            type="date"
            class="!mb-0 h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>
        <div class="flex flex-wrap gap-2 md:col-span-2 xl:col-span-3">
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.APPLY')"
            icon="i-lucide-filter"
            type="submit"
          />
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.CLEAR')"
            icon="i-lucide-rotate-ccw"
            color="slate"
            variant="faded"
            type="button"
            @click="clearFilters"
          />
        </div>
      </form>

      <div
        v-if="selectedCount"
        class="flex flex-col gap-3 border-b border-n-weak bg-n-alpha-1 p-3 sm:flex-row sm:items-center sm:justify-between"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.COUNT', {
                count: selectedCount,
              })
            }}
          </span>
          <Button
            v-if="
              !allFilteredSelected && meta.updateable_total > selectedIds.size
            "
            :label="
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.ALL_FILTERED', {
                count: meta.updateable_total,
              })
            "
            color="slate"
            variant="link"
            size="sm"
            @click="selectAllFiltered"
          />
        </div>
        <div class="flex gap-2">
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.CLEAR')"
            color="slate"
            variant="faded"
            size="sm"
            @click="resetSelection"
          />
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.OPEN')"
            icon="i-lucide-refresh-cw"
            size="sm"
            @click="openBulkUpdate"
          />
        </div>
      </div>

      <div v-if="isLoading" class="grid min-h-64 place-content-center">
        <Spinner />
      </div>
      <div v-else-if="orders.length" class="overflow-x-auto">
        <table class="w-full min-w-[1080px] border-collapse text-left">
          <thead>
            <tr class="border-b border-n-weak text-label-small text-n-slate-11">
              <th class="w-12 px-4 py-3">
                <input
                  type="checkbox"
                  :checked="allPageSelected || allFilteredSelected"
                  :disabled="
                    allFilteredSelected || selectableOrders.length === 0
                  "
                  :aria-label="
                    t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.SELECT_PAGE')
                  "
                  @change="togglePage"
                />
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.DATE') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.REFERENCE') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.RECIPIENT') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.ORDER_STATUS') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.PAYMENT_STATUS') }}
              </th>
              <th class="px-4 py-3">
                {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.LAST_UPDATE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="order in orders"
              :key="order.id"
              class="border-b border-n-weak last:border-b-0"
            >
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    :checked="allFilteredSelected || selectedIds.has(order.id)"
                    :disabled="
                      allFilteredSelected || !order.manually_updateable
                    "
                    :aria-label="
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.SELECT_ORDER',
                        { reference: order.reference_id }
                      )
                    "
                    @change="toggleOrder(order)"
                  />
                  <span
                    v-if="!order.manually_updateable"
                    v-tooltip.top="
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECTION.NOT_UPDATEABLE'
                      )
                    "
                    class="inline-flex text-n-slate-9"
                  >
                    <i class="i-lucide-lock-keyhole size-3.5" />
                  </span>
                </div>
              </td>
              <td
                class="whitespace-nowrap px-4 py-3 text-body-small text-n-slate-11"
              >
                {{ formatDate(order.created_at) }}
              </td>
              <td class="px-4 py-3 font-mono text-body-small text-n-slate-12">
                {{ order.reference_id }}
              </td>
              <td class="px-4 py-3 font-mono text-body-small text-n-slate-12">
                {{ order.recipient }}
              </td>
              <td class="px-4 py-3 text-body-small text-n-slate-12">
                {{ orderStatusLabel(order.order_status) }}
              </td>
              <td class="px-4 py-3 text-body-small text-n-slate-12">
                {{ paymentStatusLabel(order.payment_status) }}
              </td>
              <td class="px-4 py-3 text-body-small text-n-slate-11">
                {{
                  order.latest_update
                    ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.UPDATE_VALUE', {
                        status: updateStatusLabel(order.latest_update.status),
                        date: formatDate(order.latest_update.created_at),
                      })
                    : t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.TABLE.NO_UPDATE')
                }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div
        v-else
        class="grid min-h-48 place-content-center p-6 text-center text-n-slate-11"
      >
        {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.LIST.EMPTY') }}
      </div>

      <footer
        class="flex flex-col gap-3 border-t border-n-weak p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <label class="flex items-center gap-2 text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PAGINATION.PER_PAGE') }}
          <IbsoftSelect
            v-model.number="meta.per_page"
            class="w-24"
            @change="changePageSize"
          >
            <option v-for="size in pageSizes" :key="size" :value="size">
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
            :disabled="meta.page <= 1"
            @click="changePage(meta.page - 1)"
          />
          <span class="whitespace-nowrap text-label-small text-n-slate-11">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.DELIVERIES.PAGE', {
                page: meta.page,
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
            :disabled="meta.page >= totalPages"
            @click="changePage(meta.page + 1)"
          />
        </div>
      </footer>
    </section>

    <BulkOrderUpdateDialog
      ref="updateDialogRef"
      :is-saving="isUpdating"
      @save="submitBulkUpdate"
    />
  </div>
</template>
