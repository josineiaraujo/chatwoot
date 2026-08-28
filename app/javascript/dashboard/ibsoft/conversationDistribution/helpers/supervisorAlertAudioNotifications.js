import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';

const audioAlertsEnabled = () => {
  const audioAlertType =
    DashboardAudioNotificationHelper.notificationConfig?.audioAlertType || [];

  return !audioAlertType.includes('none');
};

export const notifyNewSupervisorAlerts = alerts => {
  if (!alerts?.length) return;
  if (!audioAlertsEnabled()) return;
  if (!DashboardAudioNotificationHelper.shouldPlayAlert()) return;

  DashboardAudioNotificationHelper.playAudioAlert();
};
