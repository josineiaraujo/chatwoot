import { frontendURL } from 'dashboard/helper/URLHelper';
import ChathubAnalyticsIndex from './views/Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/chathub'),
    name: 'ibsoft_chathub_home',
    component: ChathubAnalyticsIndex,
    meta: {
      permissions: [
        'administrator',
        'agent',
        'custom_role',
        'ibsoft_conversation_distribution_supervise',
      ],
      hideCopilotLauncher: true,
    },
  },
  {
    path: frontendURL('accounts/:accountId/chathub-analytics'),
    name: 'ibsoft_chathub_analytics',
    redirect: to => ({
      name: 'ibsoft_chathub_home',
      params: to.params,
      query: to.query,
      hash: to.hash,
    }),
  },
];
