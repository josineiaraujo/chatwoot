import { describe, expect, it, vi } from 'vitest';

import types from 'dashboard/store/mutation-types';
import { syncManualAssignmentState } from '../manualAssignmentStateSync';

describe('syncManualAssignmentState', () => {
  const assignment = {
    conversationId: 17,
    assignee: { id: 7, name: 'Camila' },
    assigneeType: 'User',
    team: { id: 2, name: 'Suporte' },
    status: 'open',
    snoozedUntil: null,
  };

  it('synchronizes the assignment when the conversation is still in the store', () => {
    const commit = vi.fn();

    expect(
      syncManualAssignmentState(
        { commit, conversation: { id: 17 } },
        assignment
      )
    ).toBe(true);
    expect(commit.mock.calls).toEqual([
      [
        types.ASSIGN_AGENT,
        {
          conversationId: 17,
          assignee: assignment.assignee,
          assigneeType: 'User',
        },
      ],
      [types.ASSIGN_TEAM, { conversationId: 17, team: assignment.team }],
      [
        types.CHANGE_CONVERSATION_STATUS,
        { conversationId: 17, status: 'open', snoozedUntil: null },
      ],
    ]);
  });

  it('does not mutate stale list state after the conversation leaves the store', () => {
    const commit = vi.fn();

    expect(
      syncManualAssignmentState({ commit, conversation: null }, assignment)
    ).toBe(false);
    expect(commit).not.toHaveBeenCalled();
  });
});
