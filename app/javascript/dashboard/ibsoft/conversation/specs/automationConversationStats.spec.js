import { beforeEach, describe, expect, it, vi } from 'vitest';

import ConversationApi from 'dashboard/api/inbox/conversation';
import {
  createAutomationConversationCountRefresher,
  fetchAutomationConversationCount,
} from '../automationConversationStats';
import { ALL_ASSIGNEE_TAB, PENDING_STATUS } from '../statusPresentation';

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: {
    meta: vi.fn(),
  },
}));

describe('#fetchAutomationConversationCount', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches the pending count with the active list scope', async () => {
    ConversationApi.meta.mockResolvedValue({
      data: { meta: { all_count: 7 } },
    });

    const filters = {
      inboxId: 3,
      labels: ['priority'],
      teamId: 5,
      conversationType: 'mention',
    };

    await expect(fetchAutomationConversationCount(filters)).resolves.toBe(7);
    expect(ConversationApi.meta).toHaveBeenCalledWith({
      ...filters,
      assigneeType: ALL_ASSIGNEE_TAB,
      status: PENDING_STATUS,
    });
  });
});

describe('#createAutomationConversationCountRefresher', () => {
  it('keeps the last valid count when a refresh fails', async () => {
    const onCount = vi.fn();
    const refresh = createAutomationConversationCountRefresher({
      fetchCount: vi.fn().mockRejectedValue(new Error('network error')),
      onCount,
      debounceFn: callback => callback,
    });

    await expect(refresh({ inboxId: 1 })).resolves.toBeUndefined();
    expect(onCount).not.toHaveBeenCalled();
  });

  it('ignores a stale response that finishes after a newer request', async () => {
    let resolveFirst;
    let resolveSecond;
    const fetchCount = vi
      .fn()
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFirst = resolve;
          })
      )
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveSecond = resolve;
          })
      );
    const onCount = vi.fn();
    const refresh = createAutomationConversationCountRefresher({
      fetchCount,
      onCount,
      debounceFn: callback => callback,
    });

    const firstRequest = refresh({ teamId: 1 });
    const secondRequest = refresh({ teamId: 2 });

    resolveSecond(4);
    await secondRequest;
    resolveFirst(9);
    await firstRequest;

    expect(onCount).toHaveBeenCalledTimes(1);
    expect(onCount).toHaveBeenCalledWith(4);
  });

  it('coalesces an event burst and uses the latest filters', async () => {
    vi.useFakeTimers();
    const fetchCount = vi.fn().mockResolvedValue(3);
    const onCount = vi.fn();
    const refresh = createAutomationConversationCountRefresher({
      fetchCount,
      onCount,
    });

    refresh({ teamId: 1 });
    refresh({ teamId: 2 });
    refresh({ teamId: 3 });
    await vi.runAllTimersAsync();

    expect(fetchCount).toHaveBeenCalledTimes(2);
    expect(fetchCount).toHaveBeenLastCalledWith({ teamId: 3 });
    expect(onCount).toHaveBeenCalledTimes(2);

    vi.useRealTimers();
  });
});
