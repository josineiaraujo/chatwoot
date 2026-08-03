<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNumberFormatter } from 'shared/composables/useNumberFormatter';

import Button from 'dashboard/components-next/button/Button.vue';

import PageSizeSelect from './PageSizeSelect.vue';

const props = defineProps({
  currentPage: {
    type: Number,
    required: true,
  },
  totalItems: {
    type: Number,
    required: true,
  },
  itemsPerPage: {
    type: Number,
    required: true,
  },
  pageSizeOptions: {
    type: Array,
    required: true,
  },
  defaultPageSize: {
    type: Number,
    required: true,
  },
  isRefreshing: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'refresh',
  'update:currentPage',
  'update:itemsPerPage',
]);

const { t } = useI18n();
const { formatCompactNumber, formatFullNumber } = useNumberFormatter();

const totalPages = computed(() =>
  Math.max(1, Math.ceil(props.totalItems / props.itemsPerPage))
);
const startItem = computed(
  () => (props.currentPage - 1) * props.itemsPerPage + 1
);
const endItem = computed(() =>
  Math.min(startItem.value + props.itemsPerPage - 1, props.totalItems)
);
const isFirstPage = computed(() => props.currentPage === 1);
const isLastPage = computed(() => props.currentPage === totalPages.value);

const currentPageInformation = computed(() =>
  t(
    'PAGINATION_FOOTER.SHOWING',
    {
      startItem: formatFullNumber(startItem.value),
      endItem: formatFullNumber(endItem.value),
      totalItems: formatCompactNumber(props.totalItems),
    },
    Number(props.totalItems)
  )
);

const pageInformation = computed(() =>
  t(
    'PAGINATION_FOOTER.CURRENT_PAGE_INFO',
    {
      currentPage: '',
      totalPages: formatCompactNumber(totalPages.value),
    },
    Number(totalPages.value)
  )
);

const changePage = page => {
  if (page >= 1 && page <= totalPages.value) {
    emit('update:currentPage', page);
  }
};
</script>

<template>
  <footer
    data-testid="history-pagination-footer"
    class="flex min-h-16 w-full flex-col gap-3 border-t border-n-weak bg-n-alpha-1 px-4 py-3 sm:flex-row sm:items-center sm:justify-between"
  >
    <span class="min-w-0 text-sm text-n-slate-11">
      {{ currentPageInformation }}
    </span>

    <div
      class="flex w-full flex-wrap items-center justify-between gap-2 sm:w-auto sm:justify-end"
    >
      <PageSizeSelect
        data-testid="history-page-size"
        :model-value="itemsPerPage"
        :options="pageSizeOptions"
        :default-value="defaultPageSize"
        @update:model-value="emit('update:itemsPerPage', $event)"
      />

      <Button
        v-tooltip.top="t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.REFRESH')"
        data-testid="history-refresh"
        icon="i-lucide-refresh-cw"
        color="slate"
        variant="ghost"
        size="sm"
        :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.HISTORY.REFRESH')"
        :is-loading="isRefreshing"
        @click="emit('refresh')"
      />

      <span class="hidden h-6 w-px bg-n-weak sm:block" />

      <nav
        class="flex items-center gap-1"
        :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.NAVIGATION')"
      >
        <Button
          data-testid="history-first-page"
          icon="i-lucide-chevrons-left"
          variant="ghost"
          size="sm"
          color="slate"
          class="!size-8"
          :disabled="isFirstPage"
          :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.FIRST')"
          @click="changePage(1)"
        />
        <Button
          data-testid="history-previous-page"
          icon="i-lucide-chevron-left"
          variant="ghost"
          size="sm"
          color="slate"
          class="!size-8"
          :disabled="isFirstPage"
          :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.PREVIOUS')"
          @click="changePage(currentPage - 1)"
        />

        <div class="inline-flex items-center gap-2 px-1 text-sm">
          <span
            class="rounded-md bg-n-alpha-2 px-3 py-1 font-medium tabular-nums text-n-slate-12"
          >
            {{ formatFullNumber(currentPage) }}
          </span>
          <span class="whitespace-nowrap text-n-slate-11">
            {{ pageInformation }}
          </span>
        </div>

        <Button
          data-testid="history-next-page"
          icon="i-lucide-chevron-right"
          variant="ghost"
          size="sm"
          color="slate"
          class="!size-8"
          :disabled="isLastPage"
          :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.NEXT')"
          @click="changePage(currentPage + 1)"
        />
        <Button
          data-testid="history-last-page"
          icon="i-lucide-chevrons-right"
          variant="ghost"
          size="sm"
          color="slate"
          class="!size-8"
          :disabled="isLastPage"
          :aria-label="t('IBSOFT_THEME.MESSAGE_BROADCAST.PAGINATION.LAST')"
          @click="changePage(totalPages)"
        />
      </nav>
    </div>
  </footer>
</template>
