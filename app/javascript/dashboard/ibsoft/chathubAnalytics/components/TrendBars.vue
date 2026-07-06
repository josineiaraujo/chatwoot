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
  fillHeight: {
    type: Boolean,
    default: false,
  },
});
</script>

<template>
  <div :class="fillHeight ? 'flex h-full min-h-0 flex-col' : ''">
    <p v-if="!items.length" class="mb-0 text-body-small text-n-slate-11">
      {{ emptyText }}
    </p>
    <div
      v-else
      class="flex items-end gap-2"
      :class="fillHeight ? 'min-h-56 flex-1' : 'h-44'"
    >
      <div
        v-for="item in items"
        :key="item.key"
        class="flex min-w-0 flex-1 flex-col items-center gap-2"
        :class="fillHeight ? 'h-full' : ''"
      >
        <div
          class="flex w-full items-end rounded-t-md bg-n-alpha-1"
          :class="fillHeight ? 'min-h-0 flex-1' : 'h-36'"
        >
          <div
            class="w-full rounded-t-md bg-n-brand"
            :style="{ height: `${Math.min(Math.max(item.percent || 0, 4), 100)}%` }"
            :title="item.valueLabel"
          />
        </div>
        <span class="w-full truncate text-center text-label-small text-n-slate-11">
          {{ item.label }}
        </span>
      </div>
    </div>
  </div>
</template>
