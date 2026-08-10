import { describe, expect, it } from 'vitest';
import { canViewAgentBotConversationAsQueueProfile } from '../conversationVisibility';

describe('canViewAgentBotConversationAsQueueProfile', () => {
  const agentBotConversation = {
    meta: { assignee: { id: 7 }, assignee_type: 'AgentBot' },
  };

  it('allows AgentBot conversations only for an Ibsoft access profile', () => {
    expect(
      canViewAgentBotConversationAsQueueProfile(agentBotConversation, [
        'ibsoft_access_role',
      ])
    ).toBe(true);
    expect(
      canViewAgentBotConversationAsQueueProfile(agentBotConversation, [])
    ).toBe(false);
  });

  it('does not treat a human-owned conversation as an AgentBot conversation', () => {
    const humanConversation = {
      meta: { assignee: { id: 7 }, assignee_type: 'User' },
    };

    expect(
      canViewAgentBotConversationAsQueueProfile(humanConversation, [
        'ibsoft_access_role',
      ])
    ).toBe(false);
  });
});
