import { describe, expect, it } from 'vitest';

import {
  buildMessageDateGroups,
  formatMessageTimestamp,
  isSameLocalDate,
  parseMessageDate,
} from '../helpers/messageDateGroups';

describe('#parseMessageDate', () => {
  it('accepts ISO strings, unix seconds and unix milliseconds', () => {
    const isoDate = parseMessageDate('2026-06-10T18:14:00');
    const secondsDate = parseMessageDate(1781115240);
    const millisecondsDate = parseMessageDate(1781115240000);

    expect(isoDate).toBeInstanceOf(Date);
    expect(secondsDate).toBeInstanceOf(Date);
    expect(millisecondsDate).toBeInstanceOf(Date);
    expect(secondsDate.getTime()).toBe(millisecondsDate.getTime());
  });
});

describe('#buildMessageDateGroups', () => {
  it('groups messages by local day and keeps the original message index', () => {
    const now = new Date(2026, 5, 11, 12, 0);
    const groups = buildMessageDateGroups(
      [
        { id: 1, created_at: new Date(2026, 5, 10, 18, 14).toISOString() },
        { id: 2, created_at: new Date(2026, 5, 10, 18, 16).toISOString() },
        { id: 3, created_at: new Date(2026, 5, 11, 8, 30).toISOString() },
      ],
      { locale: 'pt-BR', now, todayLabel: 'Hoje' }
    );

    expect(groups).toHaveLength(2);
    expect(groups[0].label).toBe('Quarta-feira, 10/06/2026');
    expect(groups[0].messages.map(item => item.index)).toEqual([0, 1]);
    expect(groups[1].label).toBe('Hoje');
    expect(groups[1].messages.map(item => item.message.id)).toEqual([3]);
  });
});

describe('#formatMessageTimestamp', () => {
  it('uses only the hour for messages from today', () => {
    const now = new Date(2026, 5, 11, 12, 0);

    expect(
      formatMessageTimestamp(new Date(2026, 5, 11, 8, 30), {
        locale: 'pt-BR',
        now,
      })
    ).toBe('08:30');
  });

  it('uses full date and hour for messages from previous days', () => {
    const now = new Date(2026, 5, 11, 12, 0);

    expect(
      formatMessageTimestamp(new Date(2026, 5, 10, 18, 14), {
        locale: 'pt-BR',
        now,
      })
    ).toBe('10/06/2026 18:14');
  });
});

describe('#isSameLocalDate', () => {
  it('compares by local date only', () => {
    expect(
      isSameLocalDate(
        new Date(2026, 5, 11, 0, 1),
        new Date(2026, 5, 11, 23, 59)
      )
    ).toBe(true);
  });
});
