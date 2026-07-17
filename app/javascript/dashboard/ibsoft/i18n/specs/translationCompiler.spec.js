import { createI18n } from 'vue-i18n';
import { afterEach, describe, expect, it, vi } from 'vitest';

import enTheme from '../../../i18n/locale/en/ibsoftTheme.json';
import heLogin from '../../../i18n/locale/he/login.json';
import ptBrHelpCenter from '../../../i18n/locale/pt_BR/helpCenter.json';
import ptBrTheme from '../../../i18n/locale/pt_BR/ibsoftTheme.json';
import sqIntegrations from '../../../i18n/locale/sq/integrations.json';

// Test cases intentionally select translation keys dynamically.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
const translate = ({ locale, messages, key, options }) => {
  const i18n = createI18n({
    legacy: false,
    locale,
    messages: { [locale]: messages },
  });

  return options ? i18n.global.t(key, options) : i18n.global.t(key);
};

describe('Dashboard translation compiler compatibility', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it.each([
    {
      locale: 'en',
      messages: enTheme,
      expected:
        'Your conversation was routed to {{agent.name}}. They will continue with you shortly.',
    },
    {
      locale: 'pt_BR',
      messages: ptBrTheme,
      expected:
        'Seu atendimento foi direcionado para {{agent.name}}. Em instantes ele continuará com você.',
    },
  ])('preserves the assignment token in $locale', testCase => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    const result = translate({
      ...testCase,
      key: 'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.DEFAULT_MESSAGE',
    });

    expect(result).toBe(testCase.expected);
    expect(errorSpy).not.toHaveBeenCalled();
  });

  it.each([
    {
      locale: 'pt_BR',
      messages: ptBrHelpCenter,
      key: 'HELP_CENTER.PORTAL_SETTINGS.LAYOUT_CONTENT.SOCIAL_LINKS.PLACEHOLDER',
      expected: '@usuario',
    },
    {
      locale: 'he',
      messages: heLogin,
      key: 'LOGIN.EMAIL.PLACEHOLDER',
      expected: 'example@companyname.com',
    },
  ])('renders a literal at sign in $locale', testCase => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    expect(translate(testCase)).toBe(testCase.expected);
    expect(errorSpy).not.toHaveBeenCalled();
  });

  it.each([
    'CAPTAIN.ASSISTANTS.RESPONSE_GUIDELINES.BULK_ACTION.SELECTED',
    'CAPTAIN.ASSISTANTS.SCENARIOS.BULK_ACTION.SELECTED',
  ])('compiles the Albanian plural form for %s', key => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    expect(
      translate({
        locale: 'sq',
        messages: sqIntegrations,
        key,
        options: { count: 2 },
      })
    ).toBe('2 elemente të përzgjedhura');
    expect(errorSpy).not.toHaveBeenCalled();
  });
});
