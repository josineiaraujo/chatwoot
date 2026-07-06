import { beforeEach, describe, expect, it, vi } from 'vitest';

import { audioPlaybackUrl } from '../helpers/attachmentUrls';

describe('#audioPlaybackUrl', () => {
  beforeEach(() => {
    vi.spyOn(Date, 'now').mockReturnValue(1234567890000);
  });

  it('keeps blob URLs unchanged so browser object URLs remain playable', () => {
    const url =
      'blob:http://localhost:3000/9709f53b-9b45-4442-a58a-a00e8b3160ca';

    expect(audioPlaybackUrl(url)).toBe(url);
  });

  it('keeps data URLs unchanged', () => {
    const url = 'data:audio/webm;base64,AAAA';

    expect(audioPlaybackUrl(url)).toBe(url);
  });

  it('adds a cache buster to regular URLs', () => {
    expect(audioPlaybackUrl('https://example.com/audio.mp3')).toBe(
      'https://example.com/audio.mp3?t=1234567890000'
    );
  });
});
