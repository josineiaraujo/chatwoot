import wootConstants from 'dashboard/constants/globals';

const AGENT_BOT_ASSIGNEE_TYPE = 'AgentBot';

export const isManualAssignmentAllowed = (
  conversation,
  { isAdmin = false, currentUserId = null } = {}
) => {
  const assigneeId = conversation?.meta?.assignee?.id;
  const hasHumanAssignee =
    Boolean(assigneeId) &&
    conversation?.meta?.assignee_type !== AGENT_BOT_ASSIGNEE_TYPE;

  return Boolean(
    conversation?.id &&
      conversation.status !== wootConstants.STATUS_TYPE.RESOLVED &&
      (isAdmin || !hasHumanAssignee || assigneeId === currentUserId)
  );
};
