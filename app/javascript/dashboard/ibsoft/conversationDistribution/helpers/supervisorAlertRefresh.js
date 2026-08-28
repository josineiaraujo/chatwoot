export const SUPERVISOR_ALERT_REFRESH_INTERVAL_MS = 60000;

const alertIdentity = alert => {
  if (!alert?.conversation_id || !alert?.reason) return null;

  return `${alert.conversation_id}:${alert.reason}`;
};

const alertIdentities = alerts =>
  new Set((alerts || []).map(alertIdentity).filter(Boolean));

const isCanceledRequest = error =>
  error?.name === 'AbortError' ||
  error?.name === 'CanceledError' ||
  error?.code === 'ERR_CANCELED';

export const createSupervisorAlertRefreshController = ({
  load,
  apply,
  notify = () => {},
  onError = () => {},
  intervalMs = SUPERVISOR_ALERT_REFRESH_INTERVAL_MS,
  setTimer = setTimeout,
  clearTimer = clearTimeout,
  createAbortController = () => new AbortController(),
}) => {
  let isActive = false;
  let timerId = null;
  let request = null;
  let requestController = null;
  let previousAlertIdentities = null;

  const clearScheduledRefresh = () => {
    if (timerId === null) return;

    clearTimer(timerId);
    timerId = null;
  };

  const run = () => {
    if (request) return request;

    requestController = createAbortController();
    request = Promise.resolve()
      .then(() => load({ signal: requestController.signal }))
      .then(result => {
        if (!isActive) return result;

        apply(result);

        const alerts = result?.alerts || [];
        const nextAlertIdentities = alertIdentities(alerts);
        const newAlerts =
          previousAlertIdentities === null
            ? []
            : alerts.filter(alert => {
                const identity = alertIdentity(alert);
                return identity && !previousAlertIdentities.has(identity);
              });

        previousAlertIdentities = nextAlertIdentities;
        if (newAlerts.length) notify(newAlerts);

        return result;
      })
      .catch(error => {
        if (isActive && !isCanceledRequest(error)) onError(error);
      })
      .finally(() => {
        request = null;
        requestController = null;
      });

    return request;
  };

  const scheduleRefresh = () => {
    clearScheduledRefresh();
    if (!isActive) return;

    timerId = setTimer(async () => {
      timerId = null;
      await run();
      scheduleRefresh();
    }, intervalMs);
  };

  const start = async () => {
    if (isActive) {
      await request;
      return;
    }

    isActive = true;
    await run();
    scheduleRefresh();
  };

  const refresh = async () => {
    if (!isActive) return;

    clearScheduledRefresh();
    await run();
    scheduleRefresh();
  };

  const stop = () => {
    isActive = false;
    clearScheduledRefresh();
    requestController?.abort();
  };

  return {
    start,
    refresh,
    stop,
  };
};
