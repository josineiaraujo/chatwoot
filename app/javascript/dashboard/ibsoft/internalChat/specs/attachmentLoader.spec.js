import { describe, expect, it, vi } from 'vitest';

import { loadProtectedAttachment } from '../helpers/attachmentLoader';

describe('#loadProtectedAttachment', () => {
  it('returns the attachment from the first completed response', async () => {
    const blob = new Blob(['content']);
    const request = vi.fn().mockResolvedValue({ status: 200, data: blob });

    await expect(
      loadProtectedAttachment({ url: '/attachment', request })
    ).resolves.toBe(blob);
    expect(request).toHaveBeenCalledOnce();
  });

  it('retries a preview while asynchronous processing is pending', async () => {
    const blob = new Blob(['preview']);
    const request = vi
      .fn()
      .mockResolvedValueOnce({ status: 202 })
      .mockResolvedValueOnce({ status: 200, data: blob });
    const waitForRetry = vi.fn().mockResolvedValue();

    await expect(
      loadProtectedAttachment({
        url: '/preview',
        request,
        retryPending: true,
        waitForRetry,
      })
    ).resolves.toBe(blob);
    expect(request).toHaveBeenCalledTimes(2);
    expect(waitForRetry).toHaveBeenCalledWith(750);
  });

  it('stops retrying a preview at the configured limit', async () => {
    const request = vi.fn().mockResolvedValue({ status: 202 });

    await expect(
      loadProtectedAttachment({
        url: '/preview',
        request,
        retryPending: true,
        maxAttempts: 2,
        waitForRetry: vi.fn().mockResolvedValue(),
      })
    ).resolves.toBeNull();
    expect(request).toHaveBeenCalledTimes(2);
  });
});
