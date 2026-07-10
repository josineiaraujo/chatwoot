import { describe, expect, it } from 'vitest';

import wootConstants from 'dashboard/constants/globals';
import {
  ALL_ASSIGNEE_TAB,
  getDefaultAssigneeTabForConversationType,
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
