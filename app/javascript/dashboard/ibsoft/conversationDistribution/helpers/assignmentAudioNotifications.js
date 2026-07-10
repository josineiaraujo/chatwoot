import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import WindowVisibilityHelper from 'dashboard/helper/AudioAlerts/WindowVisibilityHelper';
import { showBadgeOnFavicon } from 'dashboard/helper/AudioAlerts/faviconHelper';

const audioAlertsEnabled = () => {
  const audioAlertType =
    DashboardAudioNotificationHelper.notificationConfig?.audioAlertType || [];
  return !audioAlertType.includes('none');
};

const assignedUserId = conversation => conversation?.meta?.assignee?.id;

const currentUserId = () => DashboardAudioNotificationHelper.currentUser?.id;

const isPendingConversation = conversation =>
  conversation?.status === 'pending';

const isAssignedToCurrentUser = conversation =>
  !!currentUserId() && assignedUserId(conversation) === currentUserId();

const isCurrentConversationOpen = conversation => {
  const conversationId = conversation?.id;
  if (!conversationId) return false;

  return DashboardAudioNotificationHelper.store?.isMessageFromCurrentConversation(
    { conversation_id: conversationId }
  );
};

export const notifyConversationAssignment = conversation => {
  if (!audioAlertsEnabled()) return;
  if (isPendingConversation(conversation)) return;
  if (!isAssignedToCurrentUser(conversation)) return;
  if (
    WindowVisibilityHelper.isWindowVisible() &&
    isCurrentConversationOpen(conversation)
  ) {
    return;
  }
  if (!DashboardAudioNotificationHelper.shouldPlayAlert()) return;

  DashboardAudioNotificationHelper.playAudioAlert();
  showBadgeOnFavicon();
  DashboardAudioNotificationHelper.playAudioEvery30Seconds();
};
