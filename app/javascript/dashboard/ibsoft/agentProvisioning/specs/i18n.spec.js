import { createI18n } from 'vue-i18n';
import { describe, expect, it } from 'vitest';

import enTheme from '../../../i18n/locale/en/ibsoftTheme.json';
import ptBrTheme from '../../../i18n/locale/pt_BR/ibsoftTheme.json';

describe.each([
  ['en', enTheme, 'agent@company.com'],
  ['pt_BR', ptBrTheme, 'agente@empresa.com'],
])('Agent provisioning translations (%s)', (locale, messages, expected) => {
  it('compiles the email placeholder as literal text', () => {
    const i18n = createI18n({
      legacy: false,
      locale,
      messages: {
        [locale]: messages,
      },
    });

    expect(
      i18n.global.t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMAIL_PLACEHOLDER'
      )
    ).toBe(expected);
  });
});
