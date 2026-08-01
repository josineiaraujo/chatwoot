import { describe, expect, it } from 'vitest';

import { findSettingsSection, settingsSections } from '../settingsSections';

describe('#settingsSections', () => {
  it('declares the settings screens exposed inside ChatHub settings', () => {
    expect(settingsSections.map(section => section.id)).toEqual([
      'account',
      'erp',
      'channels',
      'message_signature',
      'external_messaging',
      'teams',
      'agent_bots',
      'integrations',
    ]);

    settingsSections.forEach(section => {
      expect(section.icon).toMatch(/^i-/);
      expect(section.labelKey).toContain('IBSOFT_THEME.CHATHUB_SETTINGS.MENU');
      expect(section.label).toEqual(expect.any(Function));
      expect(section.loader).toEqual(expect.any(Function));
    });
  });

  it('resolves labels with static translation keys', () => {
    const t = key => key;

    expect(settingsSections.map(section => section.label(t))).toEqual([
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCOUNT',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ERP',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.CHANNELS',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.MESSAGE_SIGNATURE',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.EXTERNAL_MESSAGING',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.AGENT_BOTS',
      'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.INTEGRATIONS',
    ]);
  });

  it('finds an integrated settings section by id', () => {
    expect(findSettingsSection('channels')).toMatchObject({
      id: 'channels',
      icon: 'i-lucide-messages-square',
    });
    expect(findSettingsSection('teams')).toMatchObject({
      id: 'teams',
      labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS',
    });
    expect(findSettingsSection('message_signature')).toMatchObject({
      id: 'message_signature',
      icon: 'i-lucide-signature',
    });
    expect(findSettingsSection('external_messaging')).toMatchObject({
      id: 'external_messaging',
      icon: 'i-lucide-external-link',
      labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.EXTERNAL_MESSAGING',
    });
    expect(findSettingsSection('erp')).toMatchObject({
      id: 'erp',
      icon: 'i-lucide-briefcase-business',
      labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ERP',
    });
    expect(findSettingsSection('agent_bots')).toMatchObject({
      id: 'agent_bots',
      icon: 'i-lucide-bot',
      labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.AGENT_BOTS',
    });
    expect(findSettingsSection('integrations')).toMatchObject({
      id: 'integrations',
      icon: 'i-lucide-blocks',
      labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.INTEGRATIONS',
    });
    expect(findSettingsSection('missing')).toBeUndefined();
  });
});
