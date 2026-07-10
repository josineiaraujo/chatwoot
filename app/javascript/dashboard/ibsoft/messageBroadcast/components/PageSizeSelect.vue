<script setup>
import { useI18n } from 'vue-i18n';

import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';

const props = defineProps({
  modelValue: {
    type: Number,
    required: true,
  },
  options: {
    type: Array,
    default: () => [10, 25, 50, 100],
  },
  defaultValue: {
    type: Number,
    default: 10,
  },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const updatePageSize = value => {
  emit('update:modelValue', value === '' ? props.defaultValue : Number(value));
};
</script>

<template>
  <label
    class="flex min-w-0 items-center justify-end gap-2 text-xs text-n-slate-11"
  >
    <span class="whitespace-nowrap">
      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.ITEMS_PER_PAGE') }}
    </span>
    <IbsoftSelect
      class="!w-32 shrink-0"
      :model-value="modelValue"
      :aria-label="
        t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.ITEMS_PER_PAGE')
      "
      @update:model-value="updatePageSize"
    >
      <option v-for="option in options" :key="option" :value="option">
        {{ option }}
      </option>
    </IbsoftSelect>
  </label>
</template>
