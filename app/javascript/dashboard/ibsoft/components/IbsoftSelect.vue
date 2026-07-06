<script setup>
import { computed, useAttrs } from 'vue';

import Icon from 'dashboard/components-next/icon/Icon.vue';

defineOptions({ inheritAttrs: false });

const attrs = useAttrs();
const modelValue = defineModel({
  type: [String, Number, Boolean, Object],
  default: '',
});

const selectAttrs = computed(() => {
  const { class: _class, ...rest } = attrs;
  return rest;
});
</script>

<template>
  <div class="relative w-full min-w-0" :class="attrs.class">
    <select
      v-model="modelValue"
      v-bind="selectAttrs"
      class="!mb-0 block min-h-10 w-full appearance-none rounded-lg border-0 bg-n-alpha-1 !bg-none px-3 py-2 pe-10 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-transparent transition-colors hover:outline-n-weak focus:outline-n-brand disabled:cursor-not-allowed disabled:opacity-50"
    >
      <slot />
    </select>
    <Icon
      icon="i-lucide-chevron-down"
      class="pointer-events-none absolute top-1/2 size-4 -translate-y-1/2 text-n-slate-11 ltr:right-3 rtl:left-3"
    />
  </div>
</template>
