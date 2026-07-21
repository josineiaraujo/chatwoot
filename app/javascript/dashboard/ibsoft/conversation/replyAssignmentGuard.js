import wootConstants from 'dashboard/constants/globals';

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
  const needsAssignment = assigneeId !== currentUserId;
  const needsHandoff =
    conversation.status === wootConstants.STATUS_TYPE.PENDING;

  return {
    isBlocked: needsAssignment || needsHandoff,
    needsAssignment,
    needsHandoff,
  };
};
