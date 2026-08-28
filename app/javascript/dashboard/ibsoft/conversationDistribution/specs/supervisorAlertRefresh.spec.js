import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  createSupervisorAlertRefreshController,
  SUPERVISOR_ALERT_REFRESH_INTERVAL_MS,
} from '../helpers/supervisorAlertRefresh';

const alert = ({
  conversationId = 1,
  reason = 'unassigned_waiting',
  severity = 'warning',
} = {}) => ({
  conversation_id: conversationId,
  reason,
  severity,
});

const result = alerts => ({ alerts });

describe('createSupervisorAlertRefreshController', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('uses the first successful response as a silent baseline', async () => {
    const load = vi.fn().mockResolvedValue(result([alert()]));
    const apply = vi.fn();
    const notify = vi.fn();
    const controller = createSupervisorAlertRefreshController({
      load,
      apply,
      notify,
    });

    await controller.start();

    expect(apply).toHaveBeenCalledWith(result([alert()]));
    expect(notify).not.toHaveBeenCalled();
    controller.stop();
  });

  it('refreshes on the interval and notifies once for all new alerts', async () => {
    const initialResult = result([alert()]);
    const refreshedResult = result([
      alert(),
      alert({ conversationId: 2 }),
      alert({ conversationId: 3, reason: 'assigned_without_first_reply' }),
    ]);
    const load = vi
      .fn()
      .mockResolvedValueOnce(initialResult)
      .mockResolvedValueOnce(refreshedResult);
    const notify = vi.fn();
    const controller = createSupervisorAlertRefreshController({
      load,
      apply: vi.fn(),
      notify,
    });

    await controller.start();
    await vi.advanceTimersByTimeAsync(SUPERVISOR_ALERT_REFRESH_INTERVAL_MS);

    expect(load).toHaveBeenCalledTimes(2);
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify).toHaveBeenCalledWith([
      alert({ conversationId: 2 }),
      alert({ conversationId: 3, reason: 'assigned_without_first_reply' }),
    ]);
    controller.stop();
  });

  it('does not notify again when only the severity changes', async () => {
    const load = vi
      .fn()
      .mockResolvedValueOnce(result([alert()]))
      .mockResolvedValueOnce(result([alert({ severity: 'critical' })]));
    const notify = vi.fn();
    const controller = createSupervisorAlertRefreshController({
      load,
      apply: vi.fn(),
      notify,
    });

    await controller.start();
    await controller.refresh();

    expect(notify).not.toHaveBeenCalled();
    controller.stop();
  });

  it('notifies when a resolved alert appears again later', async () => {
    const load = vi
      .fn()
      .mockResolvedValueOnce(result([alert()]))
      .mockResolvedValueOnce(result([]))
      .mockResolvedValueOnce(result([alert()]));
    const notify = vi.fn();
    const controller = createSupervisorAlertRefreshController({
      load,
      apply: vi.fn(),
      notify,
    });

    await controller.start();
    await controller.refresh();
    await controller.refresh();

    expect(notify).toHaveBeenCalledOnce();
    expect(notify).toHaveBeenCalledWith([alert()]);
    controller.stop();
  });

  it('reuses an in-flight request instead of starting concurrent refreshes', async () => {
    let resolveRefresh;
    const pendingRefresh = new Promise(resolve => {
      resolveRefresh = resolve;
    });
    const load = vi
      .fn()
      .mockResolvedValueOnce(result([]))
      .mockReturnValueOnce(pendingRefresh);
    const controller = createSupervisorAlertRefreshController({
      load,
      apply: vi.fn(),
    });

    await controller.start();
    const firstRefresh = controller.refresh();
    const secondRefresh = controller.refresh();
    await Promise.resolve();

    expect(load).toHaveBeenCalledTimes(2);

    resolveRefresh(result([]));
    await Promise.all([firstRefresh, secondRefresh]);
    controller.stop();
  });

  it('aborts the current request and stops scheduling after unmount', async () => {
    const onError = vi.fn();
    let refreshSignal;
    const load = vi
      .fn()
      .mockResolvedValueOnce(result([]))
      .mockImplementationOnce(({ signal }) => {
        refreshSignal = signal;
        return new Promise((resolve, reject) => {
          signal.addEventListener('abort', () => {
            const error = new Error('canceled');
            error.name = 'AbortError';
            reject(error);
          });
        });
      });
    const apply = vi.fn();
    const controller = createSupervisorAlertRefreshController({
      load,
      apply,
      onError,
    });

    await controller.start();
    const refresh = controller.refresh();
    await Promise.resolve();
    controller.stop();
    await refresh;
    await vi.advanceTimersByTimeAsync(SUPERVISOR_ALERT_REFRESH_INTERVAL_MS * 2);

    expect(refreshSignal.aborted).toBe(true);
    expect(onError).not.toHaveBeenCalled();
    expect(load).toHaveBeenCalledTimes(2);
    expect(apply).toHaveBeenCalledTimes(1);
  });
});
