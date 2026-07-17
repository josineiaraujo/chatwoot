const wait = delay =>
  new Promise(resolve => {
    setTimeout(resolve, delay);
  });

const loadAttachmentAttempt = async (options, attempt) => {
  const { url, request, retryPending, maxAttempts, retryDelay, waitForRetry } =
    options;
  const response = await request(url);
  if (response.status !== 202) return response.data;
  if (!retryPending || attempt === maxAttempts) return null;

  await waitForRetry(retryDelay);
  return loadAttachmentAttempt(options, attempt + 1);
};

export const loadProtectedAttachment = ({
  url,
  request,
  retryPending = false,
  maxAttempts = 8,
  retryDelay = 750,
  waitForRetry = wait,
}) =>
  loadAttachmentAttempt(
    { url, request, retryPending, maxAttempts, retryDelay, waitForRetry },
    1
  );
