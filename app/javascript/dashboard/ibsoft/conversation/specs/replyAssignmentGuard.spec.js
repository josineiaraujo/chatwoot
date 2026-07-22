import { describe, expect, it } from 'vitest';

import { getReplyAssignmentGuardState } from '../replyAssignmentGuard';

const conversation = ({
  status = 'open',
  assignee,
  assigneeType = assignee ? 'User' : undefined,
} = {}) => ({
  id: 42,
  status,
  meta: { assignee, assignee_type: assigneeType },
});

describe('getReplyAssignmentGuardState', () => {
  it('does not block a public reply owned by the current agent', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({ assignee: { id: 7 } }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: false,
      needsAssignment: false,
      needsHandoff: false,
    });
  });

  it('requires assignment for an unassigned open conversation', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation(),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: true,
      needsAssignment: true,
      needsHandoff: false,
    });
  });

  it('allows collaboration without changing the owner of an open conversation', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({ assignee: { id: 9 } }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: false,
      needsAssignment: false,
      needsHandoff: false,
    });
  });

  it('requires assignment when an agent bot owns an open conversation', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({
          assignee: { id: 9 },
          assigneeType: 'AgentBot',
        }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: true,
      needsAssignment: true,
      needsHandoff: false,
    });
  });

  it('requires only the handoff when the pending conversation is already assigned to the current agent', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({
          status: 'pending',
          assignee: { id: 7 },
        }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: true,
      needsAssignment: false,
      needsHandoff: true,
    });
  });

  it('requires assignment and handoff for an unassigned pending conversation', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({ status: 'pending' }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: true,
      needsAssignment: true,
      needsHandoff: true,
    });
  });

  it('requires assignment and handoff when another agent owns a pending conversation', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({
          status: 'pending',
          assignee: { id: 9 },
        }),
        currentUserId: 7,
      })
    ).toEqual({
      isBlocked: true,
      needsAssignment: true,
      needsHandoff: true,
    });
  });

  it('does not block private notes', () => {
    expect(
      getReplyAssignmentGuardState({
        conversation: conversation({ status: 'pending' }),
        currentUserId: 7,
        isPrivateNote: true,
      }).isBlocked
    ).toBe(false);
  });
});
