import { describe, expect, it } from 'vitest';

import { findSettingsSection, settingsSections } from '../settingsSections';

describe('#settingsSections', () => {
  it('declares the settings screens exposed inside ChatHub settings', () => {
    expect(settingsSections.map(section => section.id)).toEqual([
      'channels',
      'teams',
      'account',
    ]);

    settingsSections.forEach(section => {
      expect(section.icon).toMatch(/^i-/);
      expect(section.labelKey).toContain('IBSOFT_THEME.CHATHUB_SETTINGS.MENU');
      expect(section.loader).toEqual(expect.any(Function));
    });
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
    expect(findSettingsSection('missing')).toBeUndefined();
  });
});
