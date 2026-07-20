import { describe, expect, it } from 'vitest';

import enOverrides from 'dashboard/i18n/locale/en/ibsoftTheme.json';
import ptBROverrides from 'dashboard/i18n/locale/pt_BR/ibsoftTheme.json';

describe('Ibsoft operational conversation translations', () => {
  it('presents unassigned conversations as a queue', () => {
    expect(ptBROverrides.CHAT_LIST.ASSIGNEE_TYPE_TABS.unassigned).toBe('Fila');
    expect(enOverrides.CHAT_LIST.ASSIGNEE_TYPE_TABS.unassigned).toBe('Queue');
  });
});
