import { describe, expect, it } from 'vitest';

import wootConstants from 'dashboard/constants/globals';
import {
  ALL_ASSIGNEE_TAB,
  AUTOMATION_ASSIGNEE_TAB,
  getDefaultAssigneeTabForConversationType,
  getStatusForOperationalConversationStats,
} from '../statusPresentation';

describe('#getDefaultAssigneeTabForConversationType', () => {
  it('opens mentions with all conversations selected', () => {
    expect(
      getDefaultAssigneeTabForConversationType(
        wootConstants.CONVERSATION_TYPE.MENTION
      )
    ).toBe(ALL_ASSIGNEE_TAB);
  });

  it('keeps regular conversation lists scoped to mine by default', () => {
    expect(getDefaultAssigneeTabForConversationType()).toBe(
      wootConstants.ASSIGNEE_TYPE.ME
    );
  });

  it('does not force all conversations for other special lists', () => {
    expect(
      getDefaultAssigneeTabForConversationType(
        wootConstants.CONVERSATION_TYPE.PARTICIPATING
      )
    ).toBe(wootConstants.ASSIGNEE_TYPE.ME);
  });
});

describe('#getStatusForOperationalConversationStats', () => {
  it('uses the active status on regular assignee tabs', () => {
    expect(
      getStatusForOperationalConversationStats({
        activeAssigneeTab: wootConstants.ASSIGNEE_TYPE.ME,
        activeStatus: wootConstants.STATUS_TYPE.RESOLVED,
        lastNonAutomationStatus: wootConstants.STATUS_TYPE.OPEN,
      })
    ).toBe(wootConstants.STATUS_TYPE.RESOLVED);
  });

  it('keeps the last operational status while automation is selected', () => {
    expect(
      getStatusForOperationalConversationStats({
        activeAssigneeTab: AUTOMATION_ASSIGNEE_TAB,
        activeStatus: wootConstants.STATUS_TYPE.PENDING,
        lastNonAutomationStatus: wootConstants.STATUS_TYPE.OPEN,
      })
    ).toBe(wootConstants.STATUS_TYPE.OPEN);
  });

  it('falls back to open when automation has no previous status', () => {
    expect(
      getStatusForOperationalConversationStats({
        activeAssigneeTab: AUTOMATION_ASSIGNEE_TAB,
        activeStatus: wootConstants.STATUS_TYPE.PENDING,
      })
    ).toBe(wootConstants.STATUS_TYPE.OPEN);
  });
});
