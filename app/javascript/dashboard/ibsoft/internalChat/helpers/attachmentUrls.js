import { timeStampAppendedURL } from 'dashboard/helper/URLHelper';

export const audioPlaybackUrl = dataUrl => {
  if (!dataUrl) return '';

  const url = new URL(dataUrl, window.location.origin);
  if (['blob:', 'data:'].includes(url.protocol)) return dataUrl;

  return timeStampAppendedURL(url.toString());
};
