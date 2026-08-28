<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  closeLabel: {
    type: String,
    required: true,
  },
});

defineEmits(['close']);
</script>

<template>
  <header class="flex min-w-0 items-start justify-between gap-4">
    <div class="min-w-0">
      <h3 class="mb-0 text-base font-medium leading-6 text-n-slate-12">
        {{ title }}
      </h3>
      <p v-if="description" class="mb-0 mt-2 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </div>
    <Button
      icon="i-lucide-x"
      size="sm"
      variant="ghost"
      color="slate"
      type="button"
      class="shrink-0"
      data-test="ibsoft-dialog-close"
      :aria-label="closeLabel"
      :title="closeLabel"
      @click="$emit('close')"
    />
  </header>
</template>
