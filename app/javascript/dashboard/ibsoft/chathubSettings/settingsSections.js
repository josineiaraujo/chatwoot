export const settingsSections = Object.freeze([
  {
    id: 'account',
    icon: 'i-lucide-building-2',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCOUNT',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCOUNT'),
    loader: () =>
      import('dashboard/routes/dashboard/settings/account/Index.vue'),
  },
  {
    id: 'erp',
    icon: 'i-lucide-briefcase-business',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ERP',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ERP'),
    loader: () => import('dashboard/ibsoft/erp/views/Index.vue'),
  },
  {
    id: 'channels',
    icon: 'i-lucide-messages-square',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.CHANNELS',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.CHANNELS'),
    loader: () => import('./components/ChannelCardsPanel.vue'),
  },
  {
    id: 'teams',
    icon: 'i-lucide-users-round',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS'),
    loader: () => import('dashboard/routes/dashboard/settings/teams/Index.vue'),
  },
  {
    id: 'agent_bots',
    icon: 'i-lucide-bot',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.AGENT_BOTS',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.AGENT_BOTS'),
    loader: () =>
      import('dashboard/routes/dashboard/settings/agentBots/Index.vue'),
  },
  {
    id: 'integrations',
    icon: 'i-lucide-blocks',
    labelKey: 'IBSOFT_THEME.CHATHUB_SETTINGS.MENU.INTEGRATIONS',
    label: t => t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.INTEGRATIONS'),
    loader: () =>
      import('dashboard/routes/dashboard/settings/integrations/Index.vue'),
  },
]);

export const findSettingsSection = sectionId =>
  settingsSections.find(section => section.id === sectionId);
