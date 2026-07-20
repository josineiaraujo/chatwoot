<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import MenuItem from 'dashboard/components/widgets/conversation/contextMenu/menuItem.vue';

const props = defineProps({
  chatId: {
    type: Number,
    required: true,
  },
});

const emit = defineEmits(['open']);

const { t } = useI18n();
const store = useStore();

const conversation = computed(
  () => store.getters.getConversationById(props.chatId) || {}
);
const currentUser = computed(() => store.getters.getCurrentUser || {});
const currentTeam = computed(() => conversation.value?.meta?.team || null);
const currentAssignee = computed(
  () => conversation.value?.meta?.assignee || null
);
const isVisible = computed(
  () =>
    conversation.value?.status === 'open' &&
    currentTeam.value?.id &&
    currentAssignee.value?.id === currentUser.value?.id
);
const menuOption = computed(() => ({
  key: 'return-to-queue',
  icon: 'arrow-reply',
  label: t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.BUTTON'),
}));
</script>

<template>
  <div>
    <div v-if="isVisible">
      <MenuItem
        :option="menuOption"
        variant="icon"
        @click.stop="emit('open')"
      />
    </div>
  </div>
</template>
