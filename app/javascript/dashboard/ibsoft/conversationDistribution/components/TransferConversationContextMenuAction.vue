<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import MenuItem from 'dashboard/components/widgets/conversation/contextMenu/menuItem.vue';
import MenuItemWithSubmenu from 'dashboard/components/widgets/conversation/contextMenu/menuItemWithSubmenu.vue';

const props = defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['agent', 'queue']);
const { t } = useI18n();

const transferOption = computed(() => ({
  key: 'transfer-conversation',
  icon: 'arrow-swap',
  label: t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.BUTTON'),
}));
const agentOption = computed(() => ({
  key: 'transfer-to-agent',
  icon: 'person-add',
  label: t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT_OPTION'),
}));
const queueOption = computed(() => ({
  key: 'transfer-to-team-queue',
  icon: 'people-team-add',
  label: t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.QUEUE_OPTION'),
}));
</script>

<template>
  <MenuItemWithSubmenu
    :option="transferOption"
    :sub-menu-available="!props.disabled"
    :aria-disabled="props.disabled"
  >
    <MenuItem
      :option="agentOption"
      variant="icon"
      @click.stop="emit('agent')"
    />
    <MenuItem
      :option="queueOption"
      variant="icon"
      @click.stop="emit('queue')"
    />
  </MenuItemWithSubmenu>
</template>
