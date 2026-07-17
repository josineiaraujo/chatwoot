import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';

const AUDIO_URL = 'https://example.com/audio.ogg';

describe('Chatwoot audio loading retry backport', () => {
  let audioInstances;
  let imageInstances;

  beforeEach(() => {
    audioInstances = [];
    imageInstances = [];
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-16T12:00:00Z'));

    vi.stubGlobal('Audio', function AudioMock() {
      audioInstances.push(this);
    });
    vi.stubGlobal('Image', function ImageMock() {
      imageInstances.push(this);
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('marks the audio as loaded after metadata becomes available', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
      mediaType: 'audio',
    });

    const loading = loadWithRetry(AUDIO_URL);
    audioInstances[0].onloadedmetadata();
    await loading;

    expect(isLoaded.value).toBe(true);
    expect(hasError.value).toBe(false);
    expect(audioInstances[0].preload).toBe('metadata');
  });

  it('retries a failed audio URL with a fresh cache-busting value', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
      mediaType: 'audio',
      backOff: 1000,
    });

    const loading = loadWithRetry(AUDIO_URL);
    const firstUrl = audioInstances[0].src;
    audioInstances[0].onerror();

    await vi.advanceTimersByTimeAsync(1000);
    const secondUrl = audioInstances[1].src;
    audioInstances[1].onloadedmetadata();
    await loading;

    expect(isLoaded.value).toBe(true);
    expect(hasError.value).toBe(false);
    expect(secondUrl).not.toBe(firstUrl);
  });

  it('reports an unavailable audio after all attempts fail', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry({
      mediaType: 'audio',
      maxRetry: 3,
      backOff: 1000,
    });

    const loading = loadWithRetry(AUDIO_URL);
    audioInstances[0].onerror();
    await vi.advanceTimersByTimeAsync(1000);
    audioInstances[1].onerror();
    await vi.advanceTimersByTimeAsync(2000);
    audioInstances[2].onerror();
    await loading;

    expect(audioInstances).toHaveLength(3);
    expect(isLoaded.value).toBe(false);
    expect(hasError.value).toBe(true);
  });

  it('preserves the existing image loading behavior', async () => {
    const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry();

    const loading = loadWithRetry('https://example.com/image.png');
    imageInstances[0].onload();
    await loading;

    expect(imageInstances).toHaveLength(1);
    expect(audioInstances).toHaveLength(0);
    expect(isLoaded.value).toBe(true);
    expect(hasError.value).toBe(false);
  });
});
