<script setup>
defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  title: {
    type: String,
    required: true,
  },
});
</script>

<template>
  <section class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
    <h2 class="mb-3 text-heading-3 text-n-slate-12">
      {{ title }}
    </h2>
    <div class="space-y-2">
      <div
        v-for="item in items"
        :key="item.code"
        class="flex gap-3 rounded-lg bg-n-alpha-1 p-3"
      >
        <span
          class="mt-0.5 inline-flex size-7 shrink-0 items-center justify-center rounded-lg bg-n-blue-3 text-n-blue-11"
        >
          <i class="i-lucide-lightbulb size-4" />
        </span>
        <div class="min-w-0">
          <p class="mb-0 text-body-main font-medium text-n-slate-12">
            {{ item.title }}
          </p>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ item.description }}
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
