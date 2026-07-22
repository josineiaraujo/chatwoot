import { describe, expect, it } from 'vitest';

import ConversationAction from 'dashboard/routes/dashboard/conversation/ConversationAction.vue';
import ConversationContextMenu from 'dashboard/components/widgets/conversation/contextMenu/Index.vue';

describe('manual assignment controls', () => {
  it('disables sidebar assignment controls for resolved conversations', () => {
    expect(
      ConversationAction.computed.isManualAssignmentDisabled.call({
        currentChat: { id: 42, status: 'resolved' },
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(true);
  });

  it('disables context menu assignment controls for resolved conversations', () => {
    expect(
      ConversationContextMenu.computed.isManualAssignmentDisabled.call({
        chatId: 42,
        status: 'resolved',
        assignee: null,
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(true);
  });

  it('keeps assignment controls available for pending conversations', () => {
    expect(
      ConversationAction.computed.isManualAssignmentDisabled.call({
        currentChat: { id: 42, status: 'pending' },
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(false);
  });

  it('disables sidebar transfer controls for a regular agent when someone is assigned', () => {
    expect(
      ConversationAction.computed.isManualAssignmentDisabled.call({
        currentChat: {
          id: 42,
          status: 'open',
          meta: { assignee: { id: 7 } },
        },
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(true);
  });

  it('keeps sidebar transfer controls available to administrators', () => {
    expect(
      ConversationAction.computed.isManualAssignmentDisabled.call({
        currentChat: {
          id: 42,
          status: 'open',
          meta: { assignee: { id: 7 } },
        },
        isAdmin: true,
        currentUser: { id: 3 },
      })
    ).toBe(false);
  });

  it('disables the context transfer menu for a regular agent when someone is assigned', () => {
    expect(
      ConversationContextMenu.computed.isManualAssignmentDisabled.call({
        chatId: 42,
        status: 'open',
        assignee: { id: 7 },
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(true);
  });

  it('keeps the context transfer menu available to administrators', () => {
    expect(
      ConversationContextMenu.computed.isManualAssignmentDisabled.call({
        chatId: 42,
        status: 'open',
        assignee: { id: 7 },
        isAdmin: true,
        currentUser: { id: 3 },
      })
    ).toBe(false);
  });

  it('keeps transfer controls available to the assigned agent', () => {
    expect(
      ConversationAction.computed.isManualAssignmentDisabled.call({
        currentChat: {
          id: 42,
          status: 'open',
          meta: { assignee: { id: 7 } },
        },
        isAdmin: false,
        currentUser: { id: 7 },
      })
    ).toBe(false);

    expect(
      ConversationContextMenu.computed.isManualAssignmentDisabled.call({
        chatId: 42,
        status: 'open',
        assignee: { id: 7 },
        isAdmin: false,
        currentUser: { id: 7 },
      })
    ).toBe(false);
  });

  it('keeps context transfer controls available when the assignee is a bot', () => {
    expect(
      ConversationContextMenu.computed.isManualAssignmentDisabled.call({
        chatId: 42,
        status: 'pending',
        assignee: { id: 9 },
        assigneeType: 'AgentBot',
        isAdmin: false,
        currentUser: { id: 3 },
      })
    ).toBe(false);
  });
});
