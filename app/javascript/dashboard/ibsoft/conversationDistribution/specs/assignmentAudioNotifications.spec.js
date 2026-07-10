import { describe, expect, it, beforeEach, vi } from 'vitest';

import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import WindowVisibilityHelper from 'dashboard/helper/AudioAlerts/WindowVisibilityHelper';
import { showBadgeOnFavicon } from 'dashboard/helper/AudioAlerts/faviconHelper';
import { notifyConversationAssignment } from '../helpers/assignmentAudioNotifications';

vi.mock(
  'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper',
  () => ({
    default: {
      currentUser: { id: 7 },
      notificationConfig: { audioAlertType: ['assigned'] },
      store: {
        isMessageFromCurrentConversation: vi.fn(() => false),
      },
      playAudioAlert: vi.fn(),
      playAudioEvery30Seconds: vi.fn(),
      shouldPlayAlert: vi.fn(() => true),
    },
  })
);

vi.mock('dashboard/helper/AudioAlerts/WindowVisibilityHelper', () => ({
  default: {
    isWindowVisible: vi.fn(() => false),
  },
}));

vi.mock('dashboard/helper/AudioAlerts/faviconHelper', () => ({
  showBadgeOnFavicon: vi.fn(),
}));

const assignmentPayload = ({
  conversationId = 123,
  assigneeId = 7,
  status = 'open',
} = {}) => ({
  id: conversationId,
  status,
  meta: {
    assignee: {
      id: assigneeId,
      name: 'Agente',
    },
  },
});

describe('notifyConversationAssignment', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    DashboardAudioNotificationHelper.currentUser = { id: 7 };
    DashboardAudioNotificationHelper.notificationConfig = {
      audioAlertType: ['assigned'],
    };
    DashboardAudioNotificationHelper.shouldPlayAlert.mockReturnValue(true);
    DashboardAudioNotificationHelper.store.isMessageFromCurrentConversation.mockReturnValue(
      false
    );
    WindowVisibilityHelper.isWindowVisible.mockReturnValue(false);
  });

  it('plays the configured dashboard sound for the assigned user', () => {
    notifyConversationAssignment(assignmentPayload());

    expect(DashboardAudioNotificationHelper.playAudioAlert).toHaveBeenCalled();
    expect(showBadgeOnFavicon).toHaveBeenCalled();
    expect(
      DashboardAudioNotificationHelper.playAudioEvery30Seconds
    ).toHaveBeenCalled();
  });

  it('does not play sound for another assigned user', () => {
    notifyConversationAssignment(assignmentPayload({ assigneeId: 8 }));

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
    expect(showBadgeOnFavicon).not.toHaveBeenCalled();
  });

  it('does not play sound when audio alerts are disabled', () => {
    DashboardAudioNotificationHelper.notificationConfig = {
      audioAlertType: ['none'],
    };

    notifyConversationAssignment(assignmentPayload());

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });

  it('does not play sound for pending automation conversations', () => {
    notifyConversationAssignment(assignmentPayload({ status: 'pending' }));

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });

  it('does not play sound when the visible current conversation is assigned', () => {
    WindowVisibilityHelper.isWindowVisible.mockReturnValue(true);
    DashboardAudioNotificationHelper.store.isMessageFromCurrentConversation.mockReturnValue(
      true
    );

    notifyConversationAssignment(assignmentPayload());

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });

  it('respects the profile setting that only allows sound when applicable', () => {
    DashboardAudioNotificationHelper.shouldPlayAlert.mockReturnValue(false);

    notifyConversationAssignment(assignmentPayload());

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });
});
