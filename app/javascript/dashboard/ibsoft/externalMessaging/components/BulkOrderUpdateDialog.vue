<script setup>
import { computed, nextTick, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';

defineProps({
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save']);
const { t } = useI18n();
const dialogRef = ref(null);
const selectionCount = ref(0);
const allFiltered = ref(false);
const form = reactive({
  order_status: '',
  payment_status: '',
});

const orderStatuses = computed(() => [
  { value: '', label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.KEEP') },
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

const paymentStatuses = computed(() => [
  { value: '', label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.KEEP') },
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

const isInvalid = computed(
  () =>
    (!form.order_status && !form.payment_status) ||
    (form.order_status === 'canceled' && form.payment_status === 'captured')
);
const dialogDescription = computed(() =>
  allFiltered.value
    ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.DESCRIPTION_FILTER', {
        count: selectionCount.value,
      })
    : t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.DESCRIPTION_SELECTED', {
        count: selectionCount.value,
      })
);

const reset = () => {
  form.order_status = '';
  form.payment_status = '';
  selectionCount.value = 0;
  allFiltered.value = false;
};

const open = async selection => {
  reset();
  selectionCount.value = selection.count;
  allFiltered.value = selection.allFiltered;
  await nextTick();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const submit = () => {
  if (isInvalid.value) return;

  emit('save', {
    order_status: form.order_status || null,
    payment_status: form.payment_status || null,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    position="top"
    overflow-y-auto
    :title="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.TITLE')"
    :description="dialogDescription"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="reset"
  >
    <div class="ibsoft-external-messaging-dialog-content grid gap-4">
      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.ORDER_STATUS') }}
        </span>
        <IbsoftSelect v-model="form.order_status">
          <option
            v-for="status in orderStatuses"
            :key="status.value"
            :value="status.value"
          >
            {{ status.label }}
          </option>
        </IbsoftSelect>
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.FILTERS.PAYMENT_STATUS') }}
        </span>
        <IbsoftSelect v-model="form.payment_status">
          <option
            v-for="status in paymentStatuses"
            :key="status.value"
            :value="status.value"
          >
            {{ status.label }}
          </option>
        </IbsoftSelect>
      </label>

      <div
        class="flex items-start gap-3 rounded-lg bg-n-alpha-2 p-3 text-n-slate-11"
      >
        <i class="i-lucide-info mt-0.5 size-4 shrink-0" />
        <p class="mb-0 text-body-small">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.ASYNC_NOTICE') }}
        </p>
      </div>

      <p
        v-if="
          form.order_status === 'canceled' && form.payment_status === 'captured'
        "
        class="mb-0 text-body-small text-n-ruby-11"
      >
        {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.INVALID_COMBINATION') }}
      </p>
    </div>

    <template #footer>
      <div class="flex w-full justify-end gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          color="slate"
          variant="faded"
          @click="close"
        />
        <Button
          :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.BULK.CONFIRM')"
          icon="i-lucide-refresh-cw"
          :disabled="isInvalid || isSaving"
          :is-loading="isSaving"
          @click="submit"
        />
      </div>
    </template>
  </Dialog>
</template>
