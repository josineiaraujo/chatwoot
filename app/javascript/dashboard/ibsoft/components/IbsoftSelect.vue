<script setup>
import { computed, useAttrs } from 'vue';
import { useI18n } from 'vue-i18n';

import Icon from 'dashboard/components-next/icon/Icon.vue';

defineOptions({ inheritAttrs: false });

const attrs = useAttrs();
const { t } = useI18n();
const modelValue = defineModel({
  type: [String, Number, Boolean, Object],
  default: '',
});

const selectAttrs = computed(() => {
  const { class: _class, ...rest } = attrs;
  return rest;
});

const isDisabled = computed(() => Boolean(selectAttrs.value.disabled));
const canClear = computed(
  () =>
    !isDisabled.value &&
    modelValue.value !== '' &&
    modelValue.value !== null &&
    modelValue.value !== undefined
);

const clearSelection = () => {
  modelValue.value = '';
};
</script>

<template>
  <div class="relative box-border w-full min-w-0" :class="attrs.class">
    <select
      v-model="modelValue"
      v-bind="selectAttrs"
      class="!mb-0 block box-border min-h-10 w-full appearance-none rounded-lg border-0 bg-n-alpha-1 !bg-none px-3 py-2 pe-10 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-transparent transition-colors hover:outline-n-weak focus:outline-n-brand disabled:cursor-not-allowed disabled:opacity-50"
      :class="{ 'pe-16': canClear }"
    >
      <slot />
    </select>
    <button
      v-if="canClear"
      type="button"
      class="absolute top-1/2 z-10 flex size-5 -translate-y-1/2 items-center justify-center rounded text-n-slate-10 transition-colors hover:text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand ltr:right-8 rtl:left-8"
      :aria-label="t('IBSOFT_THEME.COMMON.CLEAR_SELECTION')"
      :title="t('IBSOFT_THEME.COMMON.CLEAR_SELECTION')"
      @click="clearSelection"
    >
      <Icon icon="i-lucide-x" class="size-4" />
    </button>
    <Icon
      icon="i-lucide-chevron-down"
      class="pointer-events-none absolute top-1/2 z-10 size-4 -translate-y-1/2 text-n-slate-11 ltr:right-3 rtl:left-3"
    />
  </div>
</template>
