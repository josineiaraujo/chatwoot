import ConversationApi from 'dashboard/api/inbox/conversation';
import { debounce } from '@chatwoot/utils';
import { ALL_ASSIGNEE_TAB, PENDING_STATUS } from './statusPresentation';

const AUTOMATION_STATS_DEBOUNCE_MS = 500;
const AUTOMATION_STATS_MAX_WAIT_MS = 2000;

export const fetchAutomationConversationCount = async ({
  inboxId,
  labels,
  teamId,
  conversationType,
}) => {
  const {
    data: { meta = {} },
  } = await ConversationApi.meta({
    inboxId,
    assigneeType: ALL_ASSIGNEE_TAB,
    status: PENDING_STATUS,
    labels,
    teamId,
    conversationType,
  });

  return meta.all_count || 0;
};

export const createAutomationConversationCountRefresher = ({
  fetchCount = fetchAutomationConversationCount,
  onCount,
  debounceFn = debounce,
}) => {
  let latestRequestId = 0;

  const refresh = async filters => {
    latestRequestId += 1;
    const requestId = latestRequestId;

    try {
      const count = await fetchCount(filters);

      if (requestId === latestRequestId) {
        onCount(count);
      }

      return count;
    } catch {
      return undefined;
    }
  };

  return debounceFn(
    refresh,
    AUTOMATION_STATS_DEBOUNCE_MS,
    false,
    AUTOMATION_STATS_MAX_WAIT_MS
  );
};
