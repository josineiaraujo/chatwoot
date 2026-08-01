import { createI18n } from 'vue-i18n';
import { afterEach, describe, expect, it, vi } from 'vitest';

import enExternalMessaging from '../../../i18n/locale/en/ibsoftExternalMessaging.json';
import enTheme from '../../../i18n/locale/en/ibsoftTheme.json';
import heLogin from '../../../i18n/locale/he/login.json';
import ptBrHelpCenter from '../../../i18n/locale/pt_BR/helpCenter.json';
import ptBrExternalMessaging from '../../../i18n/locale/pt_BR/ibsoftExternalMessaging.json';
import ptBrTheme from '../../../i18n/locale/pt_BR/ibsoftTheme.json';
import sqIntegrations from '../../../i18n/locale/sq/integrations.json';

const ibsoftLocaleBundles = import.meta.glob(
  [
    '../../../i18n/locale/en/ibsoft*.json',
    '../../../i18n/locale/pt_BR/ibsoft*.json',
  ],
  { eager: true, import: 'default' }
);

// Test cases intentionally select translation keys dynamically.
/* eslint-disable @intlify/vue-i18n/no-dynamic-keys */
const createTestI18n = ({ locale, messages }) =>
  createI18n({
    legacy: false,
    locale,
    messages: { [locale]: messages },
    warnHtmlMessage: false,
  });

const translate = ({ locale, messages, key, options }) => {
  const i18n = createTestI18n({ locale, messages });

  return options ? i18n.global.t(key, options) : i18n.global.t(key);
};

const stringMessageKeys = (messages, prefix = '') =>
  Object.entries(messages).flatMap(([key, value]) => {
    const messageKey = prefix ? `${prefix}.${key}` : key;

    if (typeof value === 'string') {
      return [messageKey];
    }

    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return stringMessageKeys(value, messageKey);
    }

    return [];
  });

describe('Dashboard translation compiler compatibility', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('compiles every private dashboard translation', () => {
    const failures = [];

    Object.entries(ibsoftLocaleBundles).forEach(([filename, messages]) => {
      const locale = filename.includes('/pt_BR/') ? 'pt_BR' : 'en';
      const i18n = createTestI18n({ locale, messages });

      stringMessageKeys(messages).forEach(key => {
        try {
          i18n.global.t(key, { count: 2, n: 2 });
        } catch (error) {
          failures.push(`${filename}:${key}: ${error.message}`);
        }
      });
    });

    expect(failures).toEqual([]);
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
      locale: 'en',
      messages: enExternalMessaging,
      expectedContract: '[field]=value||[other]=value',
    },
    {
      locale: 'pt_BR',
      messages: ptBrExternalMessaging,
      expectedContract: '[campo]=valor||[outro]=valor',
    },
  ])('renders literal IXC separators in $locale', testCase => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const keys = [
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.MSG',
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.TEXT',
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_IXC_TEXT',
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION_IXC',
    ];

    keys.forEach(key => {
      expect(translate({ ...testCase, key })).toContain(
        testCase.expectedContract
      );
    });
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
