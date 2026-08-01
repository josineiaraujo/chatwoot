import { frontendURL } from 'dashboard/helper/URLHelper';
import ChathubSettingsIndex from './views/Index.vue';
import { routes as metaTemplateRoutes } from 'dashboard/ibsoft/metaTemplates/routes';

export const IBSOFT_CHATHUB_SETTINGS_PERMISSION =
  'ibsoft_chathub_settings_manage';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/chathub-settings'),
    name: 'ibsoft_chathub_settings',
    component: ChathubSettingsIndex,
    meta: {
      permissions: ['administrator', IBSOFT_CHATHUB_SETTINGS_PERMISSION],
      hideCopilotLauncher: true,
    },
  },
  ...metaTemplateRoutes,
];
