<script setup>
import { useI18n } from 'vue-i18n';

defineProps({
  modelValue: {
    type: String,
    required: true,
  },
  options: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
</script>

<template>
  <nav
    class="mx-auto grid w-full max-w-2xl grid-cols-1 gap-1 rounded-lg bg-n-alpha-2 p-1 sm:grid-cols-3"
    :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.MODES.MENU_LABEL')"
  >
    <button
      v-for="option in options"
      :key="option.id"
      type="button"
      class="flex h-10 min-w-0 items-center justify-center gap-2 rounded-md px-3 text-sm font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-2 hover:text-n-slate-12"
      :class="{
        'bg-n-alpha-3 text-n-slate-12 shadow-sm outline outline-1 -outline-offset-1 outline-n-weak':
          modelValue === option.id,
      }"
      :aria-pressed="modelValue === option.id"
      @click="emit('update:modelValue', option.id)"
    >
      <span :class="option.icon" class="size-4 shrink-0" />
      <span class="truncate">{{ option.title }}</span>
    </button>
  </nav>
</template>
