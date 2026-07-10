<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

const props = defineProps({
  modelValue: {
    type: [String, Number],
    default: '',
  },
  options: {
    type: Array,
    default: () => [],
  },
  placeholder: {
    type: String,
    required: true,
  },
  searchPlaceholder: {
    type: String,
    required: true,
  },
  emptyState: {
    type: String,
    required: true,
  },
  loadingLabel: {
    type: String,
    required: true,
  },
  loading: {
    type: Boolean,
    default: false,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

defineOptions({
  name: 'LookupSingleSelect',
});

const query = defineModel('query', {
  type: String,
  default: '',
});

const isOpen = ref(false);
const searchInput = ref(null);

const selectedValue = computed(() => props.modelValue?.toString() || '');
const selectedOption = computed(() =>
  props.options.find(option => option.value?.toString() === selectedValue.value)
);
const triggerLabel = computed(
  () => selectedOption.value?.label || props.placeholder
);
const clearSelectionLabel = computed(() =>
  t('IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.CLEAR_SELECTION')
);

const isSelected = option => option.value?.toString() === selectedValue.value;

const openDropdown = () => {
  if (props.disabled) return;

  isOpen.value = !isOpen.value;
  if (isOpen.value) nextTick(() => searchInput.value?.focus());
};

const selectOption = option => {
  emit('update:modelValue', option.value?.toString() || '');
  query.value = '';
  isOpen.value = false;
};

const clearSelection = () => {
  emit('update:modelValue', '');
  query.value = '';
};

const closeDropdown = () => {
  isOpen.value = false;
};
</script>

<template>
  <div
    v-on-click-outside="closeDropdown"
    data-testid="lookup-single-select"
    class="relative box-border min-w-0 w-full"
  >
    <button
      type="button"
      class="flex box-border min-h-10 min-w-0 w-full items-center justify-between gap-3 rounded-lg bg-n-alpha-1 px-3 py-2 text-left text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak transition-colors hover:outline-n-slate-6 focus:outline-n-brand disabled:cursor-not-allowed disabled:opacity-60"
      :disabled="disabled"
      :aria-expanded="isOpen"
      @click="openDropdown"
    >
      <span class="min-w-0 truncate">
        {{ triggerLabel }}
      </span>
      <span class="flex shrink-0 items-center gap-2">
        <span
          v-if="selectedValue"
          role="button"
          tabindex="0"
          class="i-lucide-x size-4 text-n-slate-10 hover:text-n-slate-12"
          :aria-label="clearSelectionLabel"
          :title="clearSelectionLabel"
          @click.stop="clearSelection"
          @keydown.enter.prevent.stop="clearSelection"
          @keydown.space.prevent.stop="clearSelection"
        />
        <span
          class="i-lucide-chevron-down size-4 text-n-slate-11 transition-transform"
          :class="{ 'rotate-180': isOpen }"
        />
      </span>
    </button>

    <div
      v-if="isOpen"
      class="absolute z-50 mt-1 box-border min-w-0 w-full overflow-hidden rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
    >
      <div class="relative border-b border-n-weak">
        <span
          class="i-lucide-search absolute left-3 top-3 size-4 text-n-slate-10"
        />
        <input
          ref="searchInput"
          v-model="query"
          type="search"
          class="reset-base w-full border-0 bg-n-solid-1 py-2.5 pl-10 pr-3 text-sm text-n-slate-12 outline-none"
          :placeholder="searchPlaceholder"
        />
      </div>

      <div v-if="loading" class="px-3 py-3 text-sm text-n-slate-11">
        {{ loadingLabel }}
      </div>

      <ul v-else class="mb-0 max-h-64 overflow-y-auto py-1" role="listbox">
        <li>
          <button
            type="button"
            class="flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm text-n-slate-12 transition-colors hover:bg-n-alpha-2"
            :class="{ 'bg-n-alpha-2': !selectedValue }"
            @click="selectOption({ value: '', label: placeholder })"
          >
            <span class="min-w-0 truncate">
              {{ placeholder }}
            </span>
            <span
              v-if="!selectedValue"
              class="i-lucide-check size-4 shrink-0 text-n-brand"
            />
          </button>
        </li>

        <li
          v-if="options.length === 0"
          class="px-3 py-3 text-sm text-n-slate-11"
        >
          {{ emptyState }}
        </li>

        <li v-for="option in options" :key="option.value">
          <button
            type="button"
            class="flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm text-n-slate-12 transition-colors hover:bg-n-alpha-2"
            :class="{ 'bg-n-alpha-2': isSelected(option) }"
            @click="selectOption(option)"
          >
            <span class="min-w-0 truncate">
              {{ option.label }}
            </span>
            <span
              v-if="isSelected(option)"
              class="i-lucide-check size-4 shrink-0 text-n-brand"
            />
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
