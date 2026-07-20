<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';

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

const conversation = computed(
  () => store.getters.getConversationById(props.chatId) || {}
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
const disableConfirmButton = computed(
  () => !selectedTeam.value || isSubmitting.value
);

const open = () => {
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
  };

  return (
    messages[errorCode] ||
    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.ERROR')
  );
};

const returnToQueue = async () => {
  if (!selectedTeam.value) return;

  try {
    isSubmitting.value = true;
    await conversationDistributionAPI.returnConversationToQueue(
      props.chatId,
      selectedTeam.value.id
    );

    await Promise.all([
      store.dispatch('setCurrentChatAssignee', {
        conversationId: props.chatId,
        assignee: null,
      }),
      store.dispatch('setCurrentChatTeam', {
        conversationId: props.chatId,
        team: selectedTeam.value,
      }),
    ]);
    dialogRef.value?.close();
    useAlert(
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.QUEUE_RETURN.SUCCESS', {
        teamName: selectedTeam.value.name,
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
    @confirm="returnToQueue"
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
    </label>
  </Dialog>
</template>
