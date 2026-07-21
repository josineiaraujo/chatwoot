<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import { getReplyAssignmentGuardState } from 'dashboard/ibsoft/conversation/replyAssignmentGuard';

const props = defineProps({
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();
const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');
const isTakingOver = ref(false);

const guardState = computed(() =>
  getReplyAssignmentGuardState({
    conversation: currentChat.value,
    currentUserId: currentUser.value?.id,
    isPrivateNote: props.isOnPrivateNote,
  })
);

const bannerMessage = computed(() =>
  guardState.value.needsHandoff
    ? t('IBSOFT_THEME.CONVERSATION_REPLY_GUARD.HANDOFF_MESSAGE')
    : t('IBSOFT_THEME.CONVERSATION_REPLY_GUARD.ASSIGN_MESSAGE')
);

const actionLabel = computed(() =>
  t('IBSOFT_THEME.CONVERSATION_REPLY_GUARD.ACTION')
);

const getConversation = conversationId =>
  store.getters.getConversationById?.(conversationId) ||
  (currentChat.value?.id === conversationId ? currentChat.value : null);

const assignToCurrentUser = async (conversationId, currentUserId) => {
  await store.dispatch('assignAgent', {
    conversationId,
    agentId: currentUserId,
  });

  if (getConversation(conversationId)?.meta?.assignee?.id !== currentUserId) {
    throw new Error('Conversation assignment was not confirmed');
  }
};

const markConversationOpen = async conversationId => {
  await store.dispatch('toggleStatus', {
    conversationId,
    status: wootConstants.STATUS_TYPE.OPEN,
  });

  if (
    getConversation(conversationId)?.status !== wootConstants.STATUS_TYPE.OPEN
  ) {
    throw new Error('Conversation handoff was not confirmed');
  }
};

const takeOverConversation = async () => {
  if (isTakingOver.value || !guardState.value.isBlocked) return;

  const conversationId = currentChat.value.id;
  const currentUserId = currentUser.value.id;
  const initialGuardState = guardState.value;
  isTakingOver.value = true;

  try {
    if (initialGuardState.needsAssignment) {
      await assignToCurrentUser(conversationId, currentUserId);
    }

    if (initialGuardState.needsHandoff) {
      await markConversationOpen(conversationId);
    }

    useAlert(
      initialGuardState.needsHandoff
        ? t('CONVERSATION.BOT_HANDOFF_SUCCESS')
        : t('CONVERSATION.CHANGE_AGENT')
    );
  } catch {
    useAlert(
      initialGuardState.needsHandoff
        ? t('CONVERSATION.BOT_HANDOFF_ERROR')
        : t('CONVERSATION.CHANGE_AGENT_FAILED')
    );
  } finally {
    isTakingOver.value = false;
  }
};
</script>

<template>
  <div
    v-show="guardState.isBlocked"
    aria-live="polite"
    class="mx-2 mb-2 flex min-h-12 flex-wrap items-center justify-center gap-3 rounded-lg border border-n-slate-4 bg-n-slate-3 px-3 py-2 text-sm text-n-slate-11"
  >
    <span>{{ bannerMessage }}</span>
    <Button
      sm
      color="blue"
      variant="solid"
      class="ibsoft-reply-assignment-guard__action"
      :label="actionLabel"
      :is-loading="isTakingOver"
      :disabled="isTakingOver"
      @click="takeOverConversation"
    />
  </div>
</template>

<style scoped>
.ibsoft-reply-assignment-guard__action {
  position: relative;
  isolation: isolate;
  overflow: hidden;
}

.ibsoft-reply-assignment-guard__action::after {
  position: absolute;
  inset-block: -45%;
  inset-inline-start: -55%;
  width: 38%;
  content: '';
  pointer-events: none;
  background: linear-gradient(90deg, transparent, currentColor, transparent);
  opacity: 0.24;
  transform: skewX(-18deg);
  animation: ibsoft-reply-assignment-guard-blade 2.8s ease-in-out infinite;
}

.ibsoft-reply-assignment-guard__action:disabled::after {
  opacity: 0;
  animation: none;
}

@keyframes ibsoft-reply-assignment-guard-blade {
  0%,
  32% {
    transform: translateX(-160%) skewX(-18deg);
  }

  68%,
  100% {
    transform: translateX(520%) skewX(-18deg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .ibsoft-reply-assignment-guard__action::after {
    opacity: 0;
    animation: none;
  }
}
</style>
