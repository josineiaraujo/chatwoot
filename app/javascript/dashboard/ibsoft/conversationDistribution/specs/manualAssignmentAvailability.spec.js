import { describe, expect, it } from 'vitest';

import { isManualAssignmentAllowed } from '../manualAssignmentAvailability';

describe('isManualAssignmentAllowed', () => {
  it.each(['open', 'pending', 'snoozed'])(
    'allows manual assignment for %s conversations',
    status => {
      expect(isManualAssignmentAllowed({ id: 42, status })).toBe(true);
    }
  );

  it('blocks manual assignment for resolved conversations', () => {
    expect(isManualAssignmentAllowed({ id: 42, status: 'resolved' })).toBe(
      false
    );
  });

  it('blocks manual assignment without a conversation', () => {
    expect(isManualAssignmentAllowed(null)).toBe(false);
  });

  it('blocks a regular agent when the conversation already has an assigned agent', () => {
    expect(
      isManualAssignmentAllowed({
        id: 42,
        status: 'open',
        meta: { assignee: { id: 7 } },
      })
    ).toBe(false);
  });

  it('allows an administrator when the conversation already has an assigned agent', () => {
    expect(
      isManualAssignmentAllowed(
        {
          id: 42,
          status: 'open',
          meta: { assignee: { id: 7 } },
        },
        { isAdmin: true }
      )
    ).toBe(true);
  });

  it('allows the assigned agent to transfer their own conversation', () => {
    expect(
      isManualAssignmentAllowed(
        {
          id: 42,
          status: 'open',
          meta: { assignee: { id: 7 } },
        },
        { currentUserId: 7 }
      )
    ).toBe(true);
  });

  it('allows a regular agent when only a bot is assigned', () => {
    expect(
      isManualAssignmentAllowed({
        id: 42,
        status: 'pending',
        meta: { assignee: { id: 9 }, assignee_type: 'AgentBot' },
      })
    ).toBe(true);
  });
});
