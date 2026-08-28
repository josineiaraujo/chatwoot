<script setup>
defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  emptyText: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <div class="space-y-3">
    <p v-if="!items.length" class="mb-0 text-body-small text-n-slate-11">
      {{ emptyText }}
    </p>
    <div v-for="item in items" :key="item.key" class="space-y-1.5">
      <div class="flex items-center justify-between gap-3">
        <div class="min-w-0">
          <p class="mb-0 truncate text-body-main font-medium text-n-slate-12">
            {{ item.label }}
          </p>
          <p v-if="item.caption" class="mb-0 text-label-small text-n-slate-11">
            {{ item.caption }}
          </p>
        </div>
        <strong class="shrink-0 text-body-main text-n-slate-12">
          {{ item.valueLabel }}
        </strong>
      </div>
      <div class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
        <div
          class="h-full rounded-full bg-n-brand"
          :style="{
            width: `${Math.min(Math.max(item.percent || 0, 0), 100)}%`,
          }"
        />
      </div>
    </div>
  </div>
</template>
