import wootConstants from 'dashboard/constants/globals';

const AGENT_BOT_ASSIGNEE_TYPE = 'AgentBot';

const EMPTY_GUARD_STATE = Object.freeze({
  isBlocked: false,
  needsAssignment: false,
  needsHandoff: false,
});

export const getReplyAssignmentGuardState = ({
  conversation,
  currentUserId,
  isPrivateNote = false,
}) => {
  if (!conversation?.id || !currentUserId || isPrivateNote) {
    return EMPTY_GUARD_STATE;
  }

  const assigneeId = conversation.meta?.assignee?.id;
  const isAssignedToBot =
    conversation.meta?.assignee_type === AGENT_BOT_ASSIGNEE_TYPE;
  const needsHandoff =
    conversation.status === wootConstants.STATUS_TYPE.PENDING;
  const needsAssignment =
    !assigneeId ||
    isAssignedToBot ||
    (needsHandoff && assigneeId !== currentUserId);

  return {
    isBlocked: needsAssignment || needsHandoff,
    needsAssignment,
    needsHandoff,
  };
};
