export const settingsSections = Object.freeze([
  {
    id: 'channels',
    icon: 'i-lucide-messages-square',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.CHANNELS',
    loader: () => import('./components/ChannelCardsPanel.vue'),
  },
  {
    id: 'teams',
    icon: 'i-lucide-users-round',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS',
    loader: () => import('dashboard/routes/dashboard/settings/teams/Index.vue'),
  },
  {
    id: 'account',
    icon: 'i-lucide-building-2',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCOUNT',
    loader: () =>
      import('dashboard/routes/dashboard/settings/account/Index.vue'),
  },
]);

export const findSettingsSection = sectionId =>
  settingsSections.find(section => section.id === sectionId);
