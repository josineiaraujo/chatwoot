<script setup>
import { computed, nextTick, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
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
const endpointId = ref(null);
const keyConfigured = ref(false);
const keyHint = ref('');
const showKey = ref(false);
const activeTab = ref('payment');
const messageDefaults = ref({});
const referencePlaceholder = '{{reference_id}}';
const messageKeys = [
  'order_pending',
  'order_processing',
  'order_partially_shipped',
  'order_shipped',
  'order_completed',
  'order_canceled',
  'payment_pending',
  'payment_captured',
  'payment_failed',
  'captured_and_completed',
];
const form = reactive({
  merchant_name: '',
  key: '',
  key_type: '',
  clear_key: false,
  messages: Object.fromEntries(messageKeys.map(key => [key, ''])),
});

const keyTypes = ['CPF', 'CNPJ', 'EMAIL', 'PHONE', 'EVP'];
const tabs = computed(() => [
  {
    id: 'payment',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.TABS.PAYMENT'),
  },
  {
    id: 'messages',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.TABS.MESSAGES'),
  },
]);
const messageGroups = computed(() => [
  {
    id: 'order',
    title: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.ORDER_GROUP'),
    fields: [
      {
        key: 'order_pending',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_PENDING'
        ),
      },
      {
        key: 'order_processing',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_PROCESSING'
        ),
      },
      {
        key: 'order_partially_shipped',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_PARTIALLY_SHIPPED'
        ),
      },
      {
        key: 'order_shipped',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_SHIPPED'
        ),
      },
      {
        key: 'order_completed',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_COMPLETED'
        ),
      },
      {
        key: 'order_canceled',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.ORDER_CANCELED'
        ),
      },
    ],
  },
  {
    id: 'payment',
    title: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.PAYMENT_GROUP'),
    fields: [
      {
        key: 'payment_pending',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.PAYMENT_PENDING'
        ),
      },
      {
        key: 'payment_captured',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.PAYMENT_CAPTURED'
        ),
      },
      {
        key: 'payment_failed',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.PAYMENT_FAILED'
        ),
      },
      {
        key: 'captured_and_completed',
        label: t(
          'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.EVENTS.CAPTURED_AND_COMPLETED'
        ),
      },
    ],
  },
]);
const isInvalid = computed(
  () =>
    form.merchant_name.trim().length > 100 ||
    form.key.trim().length > 255 ||
    (form.key_type && !keyTypes.includes(form.key_type))
);

const reset = () => {
  endpointId.value = null;
  keyConfigured.value = false;
  keyHint.value = '';
  showKey.value = false;
  activeTab.value = 'payment';
  messageDefaults.value = {};
  form.merchant_name = '';
  form.key = '';
  form.key_type = '';
  form.clear_key = false;
  messageKeys.forEach(key => {
    form.messages[key] = '';
  });
};

const open = async endpoint => {
  reset();
  endpointId.value = endpoint.id;
  keyConfigured.value = Boolean(endpoint.order_defaults?.key_configured);
  keyHint.value = endpoint.order_defaults?.key_hint || '';
  form.merchant_name = endpoint.order_defaults?.merchant_name || '';
  form.key_type = endpoint.order_defaults?.key_type || '';
  messageDefaults.value = endpoint.order_defaults?.message_defaults || {};
  const messages =
    endpoint.order_defaults?.messages || messageDefaults.value || {};
  messageKeys.forEach(key => {
    form.messages[key] = messages[key] || '';
  });

  await nextTick();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const restoreMessageDefaults = () => {
  messageKeys.forEach(key => {
    form.messages[key] = messageDefaults.value[key] || '';
  });
};

const submit = () => {
  if (isInvalid.value) return;

  const orderDefaults = {
    merchant_name: form.merchant_name.trim(),
    key_type: form.key_type,
    clear_key: form.clear_key,
    messages: Object.fromEntries(
      messageKeys.map(key => [key, form.messages[key].trim()])
    ),
  };
  if (!form.clear_key && form.key.trim()) {
    orderDefaults.key = form.key.trim();
  }

  emit('save', {
    id: endpointId.value,
    payload: { order_defaults: orderDefaults },
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
    :title="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.TITLE')"
    :description="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="reset"
  >
    <div
      class="ibsoft-external-messaging-dialog-content mb-5 flex gap-1 rounded-lg bg-n-alpha-1 p-1"
      role="tablist"
      :aria-label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.TABS.LABEL')"
    >
      <Button
        v-for="tab in tabs"
        :key="tab.id"
        :label="tab.label"
        size="sm"
        type="button"
        :variant="activeTab === tab.id ? 'solid' : 'ghost'"
        :color="activeTab === tab.id ? 'blue' : 'slate'"
        class="flex-1 justify-center"
        role="tab"
        :aria-selected="activeTab === tab.id"
        @click="activeTab = tab.id"
      />
    </div>

    <div v-if="activeTab === 'payment'" class="grid gap-4" role="tabpanel">
      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MERCHANT_NAME') }}
        </span>
        <input
          v-model="form.merchant_name"
          type="text"
          maxlength="100"
          autocomplete="organization"
          class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
        />
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.KEY_TYPE') }}
        </span>
        <IbsoftSelect v-model="form.key_type">
          <option value="">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SELECT_KEY_TYPE') }}
          </option>
          <option v-for="keyType in keyTypes" :key="keyType" :value="keyType">
            {{ keyType }}
          </option>
        </IbsoftSelect>
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.PIX_KEY') }}
        </span>
        <span class="relative">
          <input
            v-model="form.key"
            :type="showKey ? 'text' : 'password'"
            maxlength="255"
            autocomplete="off"
            :disabled="form.clear_key"
            :placeholder="
              keyConfigured
                ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.KEEP_KEY', {
                    hint: keyHint,
                  })
                : ''
            "
            class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 pe-10 text-sm text-n-slate-12 disabled:opacity-50"
          />
          <button
            type="button"
            class="absolute top-1/2 grid size-8 -translate-y-1/2 place-content-center rounded-md text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 ltr:right-1 rtl:left-1"
            :aria-label="
              showKey
                ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.HIDE_KEY')
                : t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SHOW_KEY')
            "
            @click="showKey = !showKey"
          >
            <i
              class="size-4"
              :class="showKey ? 'i-lucide-eye-off' : 'i-lucide-eye'"
            />
          </button>
        </span>
        <span
          v-if="keyConfigured && !form.clear_key"
          class="text-body-small text-n-slate-10"
        >
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.KEEP_KEY_DESCRIPTION') }}
        </span>
      </label>

      <label
        v-if="keyConfigured"
        class="flex items-center justify-between gap-4 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
      >
        <span>
          <span class="block text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.REMOVE_KEY') }}
          </span>
          <span class="block text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.REMOVE_KEY_DESCRIPTION') }}
          </span>
        </span>
        <ToggleSwitch v-model="form.clear_key" />
      </label>
    </div>

    <div v-else class="grid gap-5" role="tabpanel">
      <div
        class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
      >
        <p class="mb-0 max-w-2xl text-body-small text-n-slate-11">
          {{
            t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.DESCRIPTION', {
              placeholder: referencePlaceholder,
            })
          }}
        </p>
        <Button
          :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.MESSAGES.RESTORE')"
          icon="i-lucide-rotate-ccw"
          color="slate"
          variant="faded"
          size="sm"
          type="button"
          @click="restoreMessageDefaults"
        />
      </div>

      <section
        v-for="group in messageGroups"
        :key="group.id"
        class="grid gap-3"
      >
        <h3 class="mb-0 text-heading-3 text-n-slate-12">
          {{ group.title }}
        </h3>
        <div class="grid gap-3 lg:grid-cols-2">
          <label
            v-for="field in group.fields"
            :key="field.key"
            class="grid gap-1"
          >
            <span class="text-label-small text-n-slate-11">
              {{ field.label }}
            </span>
            <textarea
              v-model="form.messages[field.key]"
              rows="2"
              maxlength="1024"
              class="min-h-20 w-full resize-y rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            />
          </label>
        </div>
      </section>
    </div>

    <template #footer>
      <div class="flex w-full items-center justify-end gap-3">
        <Button
          :label="t('DIALOG.BUTTONS.CANCEL')"
          color="slate"
          variant="faded"
          type="button"
          @click="close"
        />
        <Button
          :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.SAVE')"
          icon="i-lucide-save"
          :is-loading="isSaving"
          :disabled="isInvalid || isSaving"
          type="button"
          @click="submit"
        />
      </div>
    </template>
  </Dialog>
</template>
