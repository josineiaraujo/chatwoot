<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';
import { syncManualAssignmentState } from '../manualAssignmentStateSync';

const props = defineProps({
  chatId: {
    type: Number,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);
const selectedTeamId = ref(null);
const isSubmitting = ref(false);
const activeChatId = ref(null);

const conversation = computed(
  () =>
    store.getters.getConversationById(activeChatId.value || props.chatId) || {}
);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const currentTeam = computed(() => conversation.value?.meta?.team || null);
const availableTeams = computed(() => {
  if (
    !currentTeam.value ||
    teams.value.some(team => team.id === currentTeam.value.id)
  ) {
    return teams.value;
  }

  return [currentTeam.value, ...teams.value];
});
const selectedTeam = computed(
  () =>
    availableTeams.value.find(
      team => team.id === Number(selectedTeamId.value)
    ) || null
);
const alreadyInSelectedQueue = computed(
  () =>
    conversation.value.status === 'open' &&
    !conversation.value?.meta?.assignee &&
    currentTeam.value?.id === selectedTeam.value?.id
);
const disableConfirmButton = computed(
  () =>
    !selectedTeam.value || isSubmitting.value || alreadyInSelectedQueue.value
);

const open = () => {
  activeChatId.value = props.chatId;
  selectedTeamId.value = currentTeam.value?.id || null;
  dialogRef.value?.open();
};

const errorMessage = error => {
  const errorCode = error?.response?.data?.error;
  const messages = {
    queue_return_not_open: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_not_open'
    ),
    queue_return_actor_not_assignee: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_actor_not_assignee'
    ),
    queue_return_missing_team: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_missing_team'
    ),
    queue_return_distribution_disabled: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_distribution_disabled'
    ),
    queue_return_real_assignment_disabled: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_real_assignment_disabled'
    ),
    queue_return_native_assignment_enabled: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_native_assignment_enabled'
    ),
    queue_return_policy_disabled: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_policy_disabled'
    ),
    queue_return_source_not_allowed: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_source_not_allowed'
    ),
    queue_return_resolved: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_resolved'
    ),
    queue_return_assigned_forbidden: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_assigned_forbidden'
    ),
    queue_return_already_queued: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERRORS.queue_return_already_queued'
    ),
  };

  return (
    messages[errorCode] ||
    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERROR')
  );
};

const transferToQueue = async () => {
  if (isSubmitting.value) return;

  const team = selectedTeam.value;
  const conversationId = activeChatId.value;
  if (!team || !conversationId) return;

  try {
    isSubmitting.value = true;
    const { data } =
      await conversationDistributionAPI.returnConversationToQueue(
        conversationId,
        team.id
      );

    syncManualAssignmentState(
      {
        commit: store.commit,
        conversation: store.getters.getConversationById(conversationId),
      },
      {
        conversationId,
        assignee: null,
        team: data.team || team,
        status: data.status,
        snoozedUntil: data.snoozed_until,
      }
    );
    dialogRef.value?.close();
    useAlert(
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.SUCCESS', {
        teamName: team.name,
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
    :title="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.TITLE')"
    :description="
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.DESCRIPTION')
    "
    :confirm-button-label="
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.CONFIRM')
    "
    :is-loading="isSubmitting"
    :disable-confirm-button="disableConfirmButton"
    @confirm="transferToQueue"
  >
    <label class="grid min-w-0 gap-1">
      <span class="text-label-small text-n-slate-11">
        {{
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.TEAM_LABEL')
        }}
      </span>
      <IbsoftSelect v-model="selectedTeamId">
        <option v-for="team in availableTeams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </IbsoftSelect>
      <span
        v-if="alreadyInSelectedQueue"
        class="text-body-small text-n-slate-11"
      >
        {{
          t(
            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ALREADY_QUEUED'
          )
        }}
      </span>
    </label>
  </Dialog>
</template>
