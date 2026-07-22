import types from 'dashboard/store/mutation-types';

export const syncManualAssignmentState = (
  { commit, conversation },
  { conversationId, assignee, team, status, snoozedUntil }
) => {
  if (!conversation) return false;

  commit(types.ASSIGN_AGENT, { conversationId, assignee });
  commit(types.ASSIGN_TEAM, { conversationId, team });
  commit(types.CHANGE_CONVERSATION_STATUS, {
    conversationId,
    status,
    snoozedUntil,
  });

  return true;
};
