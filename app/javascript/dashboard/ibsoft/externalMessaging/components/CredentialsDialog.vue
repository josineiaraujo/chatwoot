<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

defineProps({
  isRotating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['rotate']);
const { t } = useI18n();

const dialogRef = ref(null);
const endpoint = ref(null);

const usesUsernameAndPassword = computed(
  () => endpoint.value?.authentication?.type === 'username_password'
);
const secretHint = computed(
  () =>
    endpoint.value?.authentication?.secret_hint || endpoint.value?.token_hint
);

const open = async value => {
  endpoint.value = value;
  await nextTick();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();
const reset = () => {
  endpoint.value = null;
};
const requestRotation = () => {
  if (endpoint.value) emit('rotate', endpoint.value);
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    position="top"
    type="alert"
    overflow-y-auto
    :title="t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.MANAGE_TITLE')"
    :description="t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.MANAGE_DESCRIPTION')"
    :cancel-button-label="
      t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.KEEP_CURRENT')
    "
    :confirm-button-label="
      t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.GENERATE_NEW')
    "
    :is-loading="isRotating"
    :disable-confirm-button="isRotating"
    @confirm="requestRotation"
    @close="reset"
  >
    <div
      v-if="endpoint"
      class="ibsoft-external-messaging-dialog-content grid gap-4"
    >
      <dl v-if="usesUsernameAndPassword" class="grid gap-3 sm:grid-cols-2">
        <div class="min-w-0 rounded-lg border border-n-weak bg-n-alpha-1 p-3">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.USERNAME') }}
          </dt>
          <dd class="mt-1 break-all font-mono text-sm text-n-slate-12">
            {{ endpoint.authentication.username }}
          </dd>
        </div>
        <div class="min-w-0 rounded-lg border border-n-weak bg-n-alpha-1 p-3">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.PASSWORD_HINT') }}
          </dt>
          <dd class="mt-1 break-all font-mono text-sm text-n-slate-12">
            {{ secretHint }}
          </dd>
        </div>
      </dl>

      <dl v-else>
        <div class="min-w-0 rounded-lg border border-n-weak bg-n-alpha-1 p-3">
          <dt class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.TOKEN_HINT') }}
          </dt>
          <dd class="mt-1 break-all font-mono text-sm text-n-slate-12">
            {{ secretHint }}
          </dd>
        </div>
      </dl>

      <div
        class="flex items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-n-slate-11"
      >
        <i class="i-lucide-triangle-alert mt-0.5 size-4 shrink-0" />
        <p class="mb-0 text-body-small">
          {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.ROTATION_WARNING') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
