<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import {
  getAgentsByUpdatedPresence,
  getSortedAgentsByAvailability,
} from 'dashboard/helper/agentHelper.js';

const props = defineProps({
  chatId: {
    type: Number,
    required: true,
  },
  inboxId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);
const selectedAgent = ref(null);
const isSubmitting = ref(false);
const isLoadingAgents = ref(false);
const activeChatId = ref(null);
const activeInboxId = ref(null);

const currentUser = computed(() => store.getters.getCurrentUser || {});
const currentAccountId = computed(() => store.getters.getCurrentAccountId);
const assignableAgents = computed(() => {
  const agents =
    store.getters['inboxAssignableAgents/getAssignableAgents'](
      activeInboxId.value || props.inboxId
    ) || [];
  const agentsWithPresence = getAgentsByUpdatedPresence(
    agents,
    currentUser.value,
    currentAccountId.value
  );

  return getSortedAgentsByAvailability(agentsWithPresence);
});
const disableConfirmButton = computed(
  () => !selectedAgent.value?.id || isSubmitting.value || isLoadingAgents.value
);

const loadAssignableAgents = async () => {
  try {
    isLoadingAgents.value = true;
    await store.dispatch('inboxAssignableAgents/fetch', [activeInboxId.value]);
  } catch (error) {
    useAlert(
      t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERRORS.LOAD_FAILED'
      )
    );
  } finally {
    isLoadingAgents.value = false;
  }
};

const open = () => {
  activeChatId.value = props.chatId;
  activeInboxId.value = props.inboxId;
  selectedAgent.value = null;
  loadAssignableAgents();
  dialogRef.value?.open();
};

const errorMessage = error => {
  const errorCode = error?.response?.data?.error;
  const messages = {
    manual_assignment_agent_not_found: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERRORS.NOT_FOUND'
    ),
    manual_assignment_invalid_target: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERRORS.INVALID_TARGET'
    ),
    manual_assignment_resolved: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERRORS.RESOLVED'
    ),
    manual_assignment_assigned_forbidden: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERRORS.FORBIDDEN'
    ),
  };

  return (
    messages[errorCode] ||
    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.ERROR')
  );
};

const transferToAgent = async () => {
  if (isSubmitting.value) return;

  const agent = selectedAgent.value;
  const conversationId = activeChatId.value;
  if (!agent?.id || !conversationId) return;

  try {
    isSubmitting.value = true;
    await store.dispatch('assignAgent', {
      conversationId,
      agentId: agent.id,
    });
    dialogRef.value?.close();
    useAlert(
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.SUCCESS', {
        agentName: agent.name,
      })
    );
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSubmitting.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="md"
    :title="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.TITLE')"
    :description="
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.DESCRIPTION')
    "
    :confirm-button-label="
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.CONFIRM')
    "
    :is-loading="isSubmitting"
    :disable-confirm-button="disableConfirmButton"
    @confirm="transferToAgent"
  >
    <label class="grid min-w-0 gap-1">
      <span class="text-label-small text-n-slate-11">
        {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.LABEL') }}
      </span>
      <MultiselectDropdown
        :options="assignableAgents"
        :selected-item="selectedAgent"
        :multiselector-title="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.TITLE')
        "
        :multiselector-placeholder="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.PLACEHOLDER')
        "
        :no-search-result="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.EMPTY')
        "
        :input-placeholder="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TRANSFER.AGENT.SEARCH')
        "
        @select="selectedAgent = $event"
      />
    </label>
  </Dialog>
</template>
