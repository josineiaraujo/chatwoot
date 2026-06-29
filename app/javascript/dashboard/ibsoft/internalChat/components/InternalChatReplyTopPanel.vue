<script setup>
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['toggle-editor-size']);

const { t } = useI18n();
</script>

<template>
  <div
    class="absolute top-2 z-10 flex items-center justify-end ltr:right-2 rtl:left-2"
  >
    <Button
      v-tooltip.top-end="
        t('IBSOFT_INTERNAL_CHAT.ACTIONS.TOGGLE_COMPOSER_HEIGHT')
      "
      ghost
      class="text-n-slate-11"
      sm
      icon="i-lucide-maximize-2"
      @click="emit('toggle-editor-size')"
    />
  </div>
</template>
