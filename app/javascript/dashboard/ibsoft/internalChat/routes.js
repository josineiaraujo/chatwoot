import { frontendURL } from 'dashboard/helper/URLHelper';
import InternalChat from './views/InternalChat.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/internal-chat'),
    name: 'ibsoft_internal_chat',
    component: InternalChat,
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
      hideCopilotLauncher: true,
    },
  },
];
