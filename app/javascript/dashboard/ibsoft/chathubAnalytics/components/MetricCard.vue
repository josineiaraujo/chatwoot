<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
  hint: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: 'i-lucide-activity',
  },
  tone: {
    type: String,
    default: 'default',
  },
});

const toneClasses = {
  default: 'bg-n-alpha-1 text-n-blue-11 ring-n-blue-5',
  success: 'bg-n-teal-3 text-n-teal-11 ring-n-teal-6',
  warning: 'bg-n-amber-3 text-n-amber-11 ring-n-amber-6',
  danger: 'bg-n-ruby-3 text-n-ruby-11 ring-n-ruby-6',
};
</script>

<template>
  <article class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
    <div class="mb-3 flex items-start justify-between gap-3">
      <p class="mb-0 text-label-small text-n-slate-11">
        {{ label }}
      </p>
      <span
        class="inline-flex size-8 shrink-0 items-center justify-center rounded-lg ring-1"
        :class="toneClasses[tone] || toneClasses.default"
      >
        <i :class="icon" />
      </span>
    </div>
    <strong class="block truncate text-heading-1 text-n-slate-12">
      {{ value }}
    </strong>
    <p v-if="hint" class="mb-0 mt-2 text-body-small text-n-slate-11">
      {{ hint }}
    </p>
  </article>
</template>
