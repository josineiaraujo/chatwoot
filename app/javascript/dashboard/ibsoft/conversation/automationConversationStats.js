import ConversationApi from 'dashboard/api/inbox/conversation';
import { ALL_ASSIGNEE_TAB, PENDING_STATUS } from './statusPresentation';

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
