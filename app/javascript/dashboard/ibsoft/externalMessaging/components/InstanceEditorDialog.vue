<script setup>
import { computed, nextTick, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import { DEFAULT_INSTANCE_TYPE } from '../instanceTypes';
import InstanceTypeMark from './InstanceTypeMark.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    default: () => [],
  },
  instanceTypes: {
    type: Array,
    default: () => [],
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['save']);
const { t } = useI18n();

const dialogRef = ref(null);
const editingEndpointId = ref(null);
const step = ref('type');
const form = reactive({
  instance_type: DEFAULT_INSTANCE_TYPE,
  name: '',
  inbox_id: '',
  active: true,
  allow_order_resends: true,
  rate_limit_per_second: 10,
  retention_days: 30,
});

const isEditing = computed(() => Boolean(editingEndpointId.value));
const selectedType = computed(() =>
  props.instanceTypes.find(type => type.value === form.instance_type)
);
const dialogTitle = computed(() => {
  if (isEditing.value) {
    return t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EDIT_TITLE');
  }

  return step.value === 'type'
    ? t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.TYPE_STEP_TITLE')
    : t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREATE_TITLE');
});
const isFormInvalid = computed(
  () =>
    !form.instance_type ||
    !form.name.trim() ||
    !form.inbox_id ||
    Number(form.rate_limit_per_second) < 1 ||
    Number(form.rate_limit_per_second) > 80 ||
    Number(form.retention_days) < 1 ||
    Number(form.retention_days) > 3650
);

const reset = () => {
  editingEndpointId.value = null;
  step.value = 'type';
  form.instance_type = DEFAULT_INSTANCE_TYPE;
  form.name = '';
  form.inbox_id = props.inboxes[0]?.id || '';
  form.active = true;
  form.allow_order_resends = true;
  form.rate_limit_per_second = 10;
  form.retention_days = 30;
};

const open = async endpoint => {
  reset();

  if (endpoint) {
    editingEndpointId.value = endpoint.id;
    step.value = 'configuration';
    form.instance_type = endpoint.instance_type;
    form.name = endpoint.name;
    form.inbox_id = endpoint.inbox_id;
    form.active = endpoint.active;
    form.allow_order_resends = endpoint.allow_order_resends !== false;
    form.rate_limit_per_second = endpoint.rate_limit_per_second;
    form.retention_days = endpoint.retention_days || 30;
  }

  await nextTick();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const submit = () => {
  if (isFormInvalid.value) return;

  const payload = {
    name: form.name.trim(),
    active: form.active,
    allow_order_resends: form.allow_order_resends,
    rate_limit_per_second: Number(form.rate_limit_per_second),
    retention_days: Number(form.retention_days),
  };

  if (!isEditing.value) {
    payload.instance_type = form.instance_type;
    payload.inbox_id = Number(form.inbox_id);
  }

  emit('save', {
    id: editingEndpointId.value,
    payload,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    position="top"
    overflow-y-auto
    :title="dialogTitle"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="reset"
  >
    <div
      v-if="step === 'type'"
      class="ibsoft-external-messaging-dialog-content grid gap-4"
    >
      <p class="mb-0 text-body-small text-n-slate-11">
        {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.TYPE_STEP_DESCRIPTION') }}
      </p>

      <button
        v-for="instanceType in instanceTypes"
        :key="instanceType.value"
        type="button"
        class="flex w-full items-start gap-3 rounded-lg border p-4 text-left transition-colors"
        :class="
          form.instance_type === instanceType.value
            ? 'border-n-brand bg-n-brand/5'
            : 'border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2'
        "
        @click="form.instance_type = instanceType.value"
      >
        <span
          class="grid h-10 w-20 shrink-0 place-content-center rounded-lg bg-n-alpha-2 px-2 text-n-slate-12"
        >
          <InstanceTypeMark
            :type-definition="instanceType"
            image-class="max-h-7 max-w-16"
          />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-sm font-medium text-n-slate-12">
            {{ instanceType.label }}
          </span>
          <span class="mt-1 block text-body-small text-n-slate-11">
            {{ instanceType.description }}
          </span>
        </span>
        <i
          class="mt-1 size-5 shrink-0"
          :class="
            form.instance_type === instanceType.value
              ? 'i-lucide-circle-check text-n-brand'
              : 'i-lucide-circle text-n-slate-9'
          "
        />
      </button>
    </div>

    <div v-else class="ibsoft-external-messaging-dialog-content grid gap-4">
      <div
        class="flex items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-3"
      >
        <span
          class="grid h-9 w-20 shrink-0 place-content-center rounded-lg bg-n-alpha-2 px-2 text-n-slate-12"
        >
          <InstanceTypeMark
            v-if="selectedType"
            :type-definition="selectedType"
            image-class="max-h-6 max-w-16"
            icon-class="size-4"
          />
        </span>
        <span class="min-w-0">
          <span class="block text-sm font-medium text-n-slate-12">
            {{ selectedType?.label }}
          </span>
          <span class="block text-body-small text-n-slate-11">
            {{ selectedType?.description }}
          </span>
        </span>
      </div>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.NAME') }}
        </span>
        <input
          v-model="form.name"
          type="text"
          class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
        />
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RETENTION_DAYS') }}
        </span>
        <input
          v-model.number="form.retention_days"
          type="number"
          min="1"
          max="3650"
          class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
        />
        <span class="text-body-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RETENTION_DESCRIPTION') }}
        </span>
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CHANNEL') }}
        </span>
        <IbsoftSelect v-model="form.inbox_id" :disabled="isEditing">
          <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
            {{ inbox.name }}
          </option>
        </IbsoftSelect>
      </label>

      <label class="grid gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RATE') }}
        </span>
        <input
          v-model.number="form.rate_limit_per_second"
          type="number"
          min="1"
          max="80"
          class="h-10 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
        />
      </label>

      <label
        class="flex items-center justify-between gap-4 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <span>
          <span class="block text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ENABLED') }}
          </span>
          <span class="block text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ENABLED_DESCRIPTION') }}
          </span>
        </span>
        <ToggleSwitch v-model="form.active" />
      </label>

      <label
        class="flex items-center justify-between gap-4 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <span>
          <span class="block text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ALLOW_ORDER_RESENDS') }}
          </span>
          <span class="block text-body-small text-n-slate-11">
            {{
              t(
                'IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ALLOW_ORDER_RESENDS_DESCRIPTION'
              )
            }}
          </span>
        </span>
        <ToggleSwitch v-model="form.allow_order_resends" />
      </label>
    </div>

    <template #footer>
      <div class="flex w-full items-center justify-between gap-3">
        <Button
          :label="
            step === 'configuration' && !isEditing
              ? t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.BACK')
              : t('DIALOG.BUTTONS.CANCEL')
          "
          :icon="
            step === 'configuration' && !isEditing ? 'i-lucide-arrow-left' : ''
          "
          color="slate"
          variant="faded"
          type="button"
          @click="
            step === 'configuration' && !isEditing ? (step = 'type') : close()
          "
        />
        <Button
          v-if="step === 'type'"
          :label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CONTINUE')"
          icon="i-lucide-arrow-right"
          trailing-icon
          :disabled="!form.instance_type"
          type="button"
          @click="step = 'configuration'"
        />
        <Button
          v-else
          :label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.SAVE')"
          icon="i-lucide-save"
          :is-loading="isSaving"
          :disabled="isFormInvalid || isSaving"
          type="button"
          @click="submit"
        />
      </div>
    </template>
  </Dialog>
</template>
