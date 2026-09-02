import { describe, expect, it, vi } from 'vitest';

import { IBSOFT_CONVERSATION_PROTOCOL_ATTRIBUTE } from '../protocol';
import { useConversationFilterContext } from 'dashboard/components-next/filter/provider';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('next/icon/provider', () => ({
  useChannelIcon: () => ({ value: null }),
}));

vi.mock(
  'dashboard/components-next/NewConversation/helpers/composeConversationHelper',
  () => ({ createContactSearcher: () => vi.fn() })
);

describe('private conversation filter provider extensions', () => {
  it('keeps the protocol filter and the operational pending label', () => {
    const { filterTypes } = useConversationFilterContext();
    const protocolFilter = filterTypes.value.find(
      filter => filter.attributeKey === IBSOFT_CONVERSATION_PROTOCOL_ATTRIBUTE
    );
    const statusFilter = filterTypes.value.find(
      filter => filter.attributeKey === 'status'
    );

    expect(protocolFilter).toMatchObject({
      inputType: 'plainText',
      dataType: 'text',
      attributeModel: 'standard',
    });
    expect(protocolFilter.filterOperators).toHaveLength(1);
    expect(
      statusFilter.options.find(option => option.id === 'pending')
    ).toEqual({
      id: 'pending',
      name: 'IBSOFT_THEME.CONVERSATION_STATUS.PENDING_OPERATIONAL',
    });
  });
});
