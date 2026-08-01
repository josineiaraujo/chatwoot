import { frontendURL } from 'dashboard/helper/URLHelper';
import ExternalMessagingIndex from './views/Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/external-messaging'),
    name: 'ibsoft_external_messaging',
    component: ExternalMessagingIndex,
    meta: {
      permissions: ['administrator'],
      hideCopilotLauncher: true,
    },
  },
];
