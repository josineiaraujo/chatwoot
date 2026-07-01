import { emitter } from 'shared/helpers/mitt';
import { PENDING_STATUS } from './statusPresentation';

export const shouldRefreshAutomationConversationStats = ({
  previousStatus,
  nextStatus,
}) => previousStatus === PENDING_STATUS || nextStatus === PENDING_STATUS;

export const emitConversationStatsRefresh = () => {
  emitter.emit('fetch_conversation_stats');
};

export const refreshConversationStatsAfterStatusChange = ({
  previousStatus,
  nextStatus,
}) => {
  if (
    shouldRefreshAutomationConversationStats({ previousStatus, nextStatus })
  ) {
    emitConversationStatsRefresh();
  }
};
