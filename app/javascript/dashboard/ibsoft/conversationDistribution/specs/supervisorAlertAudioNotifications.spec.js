import { beforeEach, describe, expect, it, vi } from 'vitest';

import DashboardAudioNotificationHelper from 'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper';
import { notifyNewSupervisorAlerts } from '../helpers/supervisorAlertAudioNotifications';

vi.mock(
  'dashboard/helper/AudioAlerts/DashboardAudioNotificationHelper',
  () => ({
    default: {
      notificationConfig: { audioAlertType: ['assigned'] },
      playAudioAlert: vi.fn(),
      shouldPlayAlert: vi.fn(() => true),
    },
  })
);

describe('notifyNewSupervisorAlerts', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    DashboardAudioNotificationHelper.notificationConfig = {
      audioAlertType: ['assigned'],
    };
    DashboardAudioNotificationHelper.shouldPlayAlert.mockReturnValue(true);
  });

  it('plays one configured dashboard sound for one or more new alerts', () => {
    notifyNewSupervisorAlerts([{ conversation_id: 1 }, { conversation_id: 2 }]);

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).toHaveBeenCalledTimes(1);
  });

  it('does not play sound without new alerts', () => {
    notifyNewSupervisorAlerts([]);

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });

  it('respects disabled audio alerts in the user profile', () => {
    DashboardAudioNotificationHelper.notificationConfig = {
      audioAlertType: ['none'],
    };

    notifyNewSupervisorAlerts([{ conversation_id: 1 }]);

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });

  it('respects the profile rule for when dashboard audio may play', () => {
    DashboardAudioNotificationHelper.shouldPlayAlert.mockReturnValue(false);

    notifyNewSupervisorAlerts([{ conversation_id: 1 }]);

    expect(
      DashboardAudioNotificationHelper.playAudioAlert
    ).not.toHaveBeenCalled();
  });
});
