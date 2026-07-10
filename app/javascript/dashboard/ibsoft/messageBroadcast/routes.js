import { frontendURL } from 'dashboard/helper/URLHelper';
import MessageBroadcastIndex from './views/Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/message-broadcast'),
    name: 'ibsoft_message_broadcast',
    component: MessageBroadcastIndex,
    meta: {
      permissions: ['administrator'],
      hideCopilotLauncher: true,
    },
  },
];
