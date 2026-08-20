<script setup>
import { computed, nextTick, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import externalMessagingAPI from '../api';

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
const orderUpdateTemplates = ref([]);
const isLoadingTemplates = ref(false);
const templatesLoadFailed = ref(false);
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
  update_delivery: {
    mode: 'interactive',
    default_template_id: '',
    overrides: Object.fromEntries(messageKeys.map(key => [key, ''])),
  },
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
  {
    id: 'delivery',
    label: t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.TABS.DELIVERY'),
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
const updateEvents = computed(() =>
  messageGroups.value.flatMap(group => group.fields)
);
const selectedDefaultTemplate = computed(() =>
  orderUpdateTemplates.value.find(
    template => template.id === form.update_delivery.default_template_id
  )
);
const isInvalid = computed(
  () =>
    form.merchant_name.trim().length > 100 ||
    form.key.trim().length > 255 ||
    (form.key_type && !keyTypes.includes(form.key_type)) ||
    (form.update_delivery.mode === 'template' &&
      !form.update_delivery.default_template_id)
);

const templateBehaviorLabel = template =>
  template?.body_parameter
    ? t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.TEMPLATE_USES_MESSAGE')
    : t(
        'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.TEMPLATE_WITHOUT_VARIABLE'
      );

const templateOptionLabel = template =>
  t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.TEMPLATE_OPTION', {
    name: template.name,
    language: template.language,
    behavior: templateBehaviorLabel(template),
  });

const fetchOrderUpdateTemplates = async () => {
  if (!endpointId.value || isLoadingTemplates.value) return;

  isLoadingTemplates.value = true;
  templatesLoadFailed.value = false;
  try {
    const { data } = await externalMessagingAPI.getOrderUpdateTemplates(
      endpointId.value
    );
    orderUpdateTemplates.value = data.templates || [];
  } catch {
    templatesLoadFailed.value = true;
  } finally {
    isLoadingTemplates.value = false;
  }
};

const reset = () => {
  endpointId.value = null;
  keyConfigured.value = false;
  keyHint.value = '';
  showKey.value = false;
  activeTab.value = 'payment';
  messageDefaults.value = {};
  orderUpdateTemplates.value = [];
  isLoadingTemplates.value = false;
  templatesLoadFailed.value = false;
  form.merchant_name = '';
  form.key = '';
  form.key_type = '';
  form.clear_key = false;
  messageKeys.forEach(key => {
    form.messages[key] = '';
    form.update_delivery.overrides[key] = '';
  });
  form.update_delivery.mode = 'interactive';
  form.update_delivery.default_template_id = '';
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
  const updateDelivery = endpoint.order_defaults?.update_delivery || {};
  orderUpdateTemplates.value = [
    updateDelivery.default_template,
    ...Object.values(updateDelivery.overrides || {}),
  ].filter(
    (template, index, templates) =>
      template?.id &&
      templates.findIndex(candidate => candidate?.id === template.id) === index
  );
  form.update_delivery.mode = updateDelivery.mode || 'interactive';
  form.update_delivery.default_template_id =
    updateDelivery.default_template?.id?.toString() || '';
  messageKeys.forEach(key => {
    form.update_delivery.overrides[key] =
      updateDelivery.overrides?.[key]?.id?.toString() || '';
  });

  await nextTick();
  dialogRef.value?.open();
  fetchOrderUpdateTemplates();
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
    update_delivery: {
      mode: form.update_delivery.mode,
      ...(form.update_delivery.mode === 'template'
        ? {
            default_template_id: form.update_delivery.default_template_id,
            overrides: Object.fromEntries(
              messageKeys
                .map(key => [key, form.update_delivery.overrides[key]])
                .filter(([, templateId]) => templateId)
            ),
          }
        : {}),
    },
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

    <div
      v-else-if="activeTab === 'messages'"
      class="grid gap-5"
      role="tabpanel"
    >
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

    <div v-else class="grid gap-5" role="tabpanel">
      <section class="grid gap-3">
        <div>
          <h3 class="mb-1 text-heading-3 text-n-slate-12">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.MODE_TITLE')
            }}
          </h3>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t(
                'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.MODE_DESCRIPTION'
              )
            }}
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <button
            type="button"
            class="flex min-h-28 items-start gap-3 rounded-lg border p-4 text-left transition-colors"
            :class="
              form.update_delivery.mode === 'interactive'
                ? 'border-n-blue-8 bg-n-blue-3'
                : 'border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2'
            "
            @click="form.update_delivery.mode = 'interactive'"
          >
            <i
              class="i-lucide-mouse-pointer-click mt-0.5 size-5 shrink-0 text-n-blue-10"
            />
            <span>
              <span class="block text-sm font-medium text-n-slate-12">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.INTERACTIVE_TITLE'
                  )
                }}
              </span>
              <span class="mt-1 block text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.INTERACTIVE_DESCRIPTION'
                  )
                }}
              </span>
            </span>
          </button>

          <button
            type="button"
            class="flex min-h-28 items-start gap-3 rounded-lg border p-4 text-left transition-colors"
            :class="
              form.update_delivery.mode === 'template'
                ? 'border-n-blue-8 bg-n-blue-3'
                : 'border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2'
            "
            @click="form.update_delivery.mode = 'template'"
          >
            <i
              class="i-lucide-file-text mt-0.5 size-5 shrink-0 text-n-blue-10"
            />
            <span>
              <span class="block text-sm font-medium text-n-slate-12">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.TEMPLATE_TITLE'
                  )
                }}
              </span>
              <span class="mt-1 block text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.TEMPLATE_DESCRIPTION'
                  )
                }}
              </span>
            </span>
          </button>
        </div>
      </section>

      <template v-if="form.update_delivery.mode === 'template'">
        <div
          v-if="isLoadingTemplates"
          class="grid min-h-36 place-content-center gap-3 text-center text-n-slate-11"
        >
          <Spinner />
          <span class="text-body-small">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.LOADING') }}
          </span>
        </div>

        <div
          v-else-if="templatesLoadFailed && !orderUpdateTemplates.length"
          class="flex min-h-36 flex-col items-center justify-center gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-5 text-center"
        >
          <i class="i-lucide-cloud-off size-5 text-n-slate-10" />
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.LOAD_ERROR')
            }}
          </p>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.RETRY')"
            icon="i-lucide-refresh-cw"
            color="slate"
            variant="faded"
            size="sm"
            type="button"
            @click="fetchOrderUpdateTemplates"
          />
        </div>

        <div
          v-else-if="!orderUpdateTemplates.length"
          class="flex min-h-36 flex-col items-center justify-center gap-2 rounded-lg border border-n-weak bg-n-alpha-1 p-5 text-center"
        >
          <i class="i-lucide-file-search size-5 text-n-slate-10" />
          <p class="mb-0 max-w-xl text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.EMPTY') }}
          </p>
        </div>

        <template v-else>
          <div
            v-if="templatesLoadFailed"
            class="flex items-center justify-between gap-3 rounded-lg border border-n-amber-5 bg-n-amber-3 p-3"
          >
            <span
              class="flex items-center gap-2 text-body-small text-n-amber-11"
            >
              <i class="i-lucide-triangle-alert size-4 shrink-0" />
              {{
                t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.LOAD_ERROR')
              }}
            </span>
            <Button
              :label="
                t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.RETRY')
              "
              icon="i-lucide-refresh-cw"
              color="slate"
              variant="faded"
              size="sm"
              type="button"
              @click="fetchOrderUpdateTemplates"
            />
          </div>

          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.DEFAULT_LABEL'
                )
              }}
            </span>
            <IbsoftSelect v-model="form.update_delivery.default_template_id">
              <option value="">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.DEFAULT_PLACEHOLDER'
                  )
                }}
              </option>
              <option
                v-for="template in orderUpdateTemplates"
                :key="template.id"
                :value="template.id"
              >
                {{ templateOptionLabel(template) }}
              </option>
            </IbsoftSelect>
            <span class="text-body-small text-n-slate-10">
              {{
                t(
                  'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.DEFAULT_DESCRIPTION'
                )
              }}
            </span>
          </label>

          <div
            v-if="selectedDefaultTemplate"
            class="flex items-center gap-2 rounded-lg border border-n-weak bg-n-alpha-1 p-3 text-body-small text-n-slate-11"
          >
            <i class="i-lucide-info size-4 shrink-0 text-n-blue-10" />
            {{ templateBehaviorLabel(selectedDefaultTemplate) }}
          </div>

          <section class="grid gap-3">
            <div>
              <h3 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.OVERRIDES_TITLE'
                  )
                }}
              </h3>
              <p class="mb-0 text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.OVERRIDES_DESCRIPTION'
                  )
                }}
              </p>
            </div>

            <div class="grid gap-3 lg:grid-cols-2">
              <label
                v-for="event in updateEvents"
                :key="event.key"
                class="grid gap-1"
              >
                <span class="text-label-small text-n-slate-11">
                  {{ event.label }}
                </span>
                <IbsoftSelect
                  v-model="form.update_delivery.overrides[event.key]"
                >
                  <option value="">
                    {{
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.ORDERS.MODAL.DELIVERY.USE_DEFAULT'
                      )
                    }}
                  </option>
                  <option
                    v-for="template in orderUpdateTemplates"
                    :key="template.id"
                    :value="template.id"
                  >
                    {{ templateOptionLabel(template) }}
                  </option>
                </IbsoftSelect>
              </label>
            </div>
          </section>
        </template>
      </template>
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
