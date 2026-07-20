import wootConstants from 'dashboard/constants/globals';

export const PENDING_STATUS = wootConstants.STATUS_TYPE.PENDING;
export const ALL_ASSIGNEE_TAB = wootConstants.ASSIGNEE_TYPE.ALL;
export const AUTOMATION_ASSIGNEE_TAB = 'ibsoft_automation';

export const getConversationStatusLabelKey = status => {
  if (status === PENDING_STATUS) {
    return 'IBSOFT_THEME.CONVERSATION_STATUS.PENDING_OPERATIONAL';
  }

  return `CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`;
};

export const getConversationStatusLabel = (translate, status) =>
  translate(getConversationStatusLabelKey(status));

export const getDefaultAssigneeTabForConversationType = conversationType =>
  conversationType === wootConstants.CONVERSATION_TYPE.MENTION
    ? ALL_ASSIGNEE_TAB
    : wootConstants.ASSIGNEE_TYPE.ME;

export const canManuallyMarkConversationPending = false;

export const visibleManualConversationStatusOptions = options =>
  options.filter(option => option?.key !== PENDING_STATUS);

export const isAutomationAssigneeTab = tab => tab === AUTOMATION_ASSIGNEE_TAB;

export const getAssigneeTypeForConversationTab = tab => {
  if (isAutomationAssigneeTab(tab)) {
    return ALL_ASSIGNEE_TAB;
  }

  return tab;
};

export const getStatusForConversationTab = (tab, status) => {
  if (isAutomationAssigneeTab(tab)) {
    return PENDING_STATUS;
  }

  return status;
};

export const getStatusForOperationalConversationStats = ({
  activeAssigneeTab,
  activeStatus,
  lastNonAutomationStatus,
}) => {
  if (isAutomationAssigneeTab(activeAssigneeTab)) {
    return lastNonAutomationStatus || wootConstants.STATUS_TYPE.OPEN;
  }

  return activeStatus;
};

export const getConversationPageFilterKey = ({
  hasAppliedFiltersOrActiveFolders,
  activeAssigneeTab,
}) => {
  if (hasAppliedFiltersOrActiveFolders) {
    return 'appliedFilters';
  }

  return activeAssigneeTab;
};

export const buildOperationalAssigneeTabItems = ({
  items,
  translate,
  automationCount = 0,
}) => {
  const primaryItems = [];
  const overflowItems = [];

  items.forEach(item => {
    if (item.key !== ALL_ASSIGNEE_TAB) {
      primaryItems.push(item);
      return;
    }

    primaryItems.push({
      ...item,
      key: AUTOMATION_ASSIGNEE_TAB,
      name: translate('IBSOFT_THEME.CONVERSATION_TABS.AUTOMATION'),
      count: automationCount,
    });
    overflowItems.push(item);
  });

  return { primaryItems, overflowItems };
};
