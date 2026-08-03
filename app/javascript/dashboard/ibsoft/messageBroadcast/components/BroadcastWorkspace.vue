<script setup>
import { onBeforeUnmount, onMounted } from 'vue';

import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';

defineProps({
  title: { type: String, required: true },
  closeLabel: { type: String, required: true },
  steps: { type: Array, required: true },
  activeStep: { type: String, required: true },
});

const emit = defineEmits(['close', 'select-step']);

const handleEscape = event => {
  if (event.key !== 'Escape' || document.querySelector('dialog[open]')) return;
  emit('close');
};

onMounted(() => document.addEventListener('keydown', handleEscape));
onBeforeUnmount(() => document.removeEventListener('keydown', handleEscape));
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      class="fixed inset-0 z-[100] flex min-h-0 flex-col bg-n-background"
      data-testid="message-broadcast-workspace"
    >
      <header
        class="flex h-16 shrink-0 items-center gap-3 border-b border-n-weak px-4 md:px-6"
      >
        <Button
          type="button"
          icon="i-lucide-x"
          color="slate"
          variant="ghost"
          :aria-label="closeLabel"
          @click="emit('close')"
        />
        <h1 class="m-0 truncate text-heading-1 text-n-slate-12">
          {{ title }}
        </h1>
      </header>

      <nav
        class="shrink-0 overflow-x-auto border-b border-n-weak px-4 py-3 md:px-6"
      >
        <div class="mx-auto grid min-w-[48rem] max-w-6xl grid-cols-5 gap-2">
          <button
            v-for="step in steps"
            :key="step.id"
            type="button"
            class="flex items-center justify-center gap-2 rounded-lg px-3 py-3 text-sm font-medium text-n-slate-11 transition-colors"
            :class="{
              'bg-n-alpha-2 text-n-slate-12': activeStep === step.id,
              'cursor-not-allowed opacity-50': step.disabled,
              'hover:bg-n-alpha-1': !step.disabled,
            }"
            :disabled="step.disabled"
            @click="emit('select-step', step.id)"
          >
            <span
              class="grid size-7 shrink-0 place-content-center rounded-full border border-n-weak"
              :class="{
                'border-n-brand bg-n-brand text-white': activeStep === step.id,
              }"
            >
              <i class="size-4" :class="step.icon" />
            </span>
            <span class="truncate">{{ step.label }}</span>
          </button>
        </div>
      </nav>

      <main class="min-h-0 min-w-0 flex-1 overflow-y-auto">
        <div class="mx-auto w-full max-w-6xl p-4 pb-10 md:p-6 md:pb-12">
          <slot />
        </div>
      </main>
    </div>
  </TeleportWithDirection>
</template>
