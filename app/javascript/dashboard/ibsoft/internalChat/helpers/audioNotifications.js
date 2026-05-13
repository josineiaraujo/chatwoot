import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import { showBadgeOnFavicon } from 'dashboard/helper/AudioAlerts/faviconHelper';

let activeRoomId = null;

export const setActiveInternalChatRoom = roomId => {
  activeRoomId = roomId ? Number(roomId) : null;
};

export const clearActiveInternalChatRoom = () => {
  activeRoomId = null;
};

const isCurrentRoomOpen = roomId =>
  activeRoomId !== null && Number(roomId) === activeRoomId;

const audioAlertsEnabled = () => {
  const audioAlertType =
    DashboardAudioNotificationHelper.notificationConfig?.audioAlertType || [];
  return !audioAlertType.includes('none');
};

const isOwnMessage = message => {
  const currentUser = DashboardAudioNotificationHelper.currentUser;
  return !!currentUser?.id && message?.sender?.id === currentUser.id;
};

export const notifyNewInternalChatMessage = payload => {
  if (!audioAlertsEnabled()) return;
  if (isCurrentRoomOpen(payload?.room_id)) return;
  if (isOwnMessage(payload?.message)) return;
  if (!DashboardAudioNotificationHelper.shouldPlayAlert()) return;

  DashboardAudioNotificationHelper.playAudioAlert();
  showBadgeOnFavicon();
};
