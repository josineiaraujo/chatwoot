import { frontendURL } from 'dashboard/helper/URLHelper';
import MessageBroadcastIndex from './views/Index.vue';
import { IBSOFT_MESSAGE_BROADCAST_PERMISSION } from './permissions';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/message-broadcast'),
    name: 'ibsoft_message_broadcast',
    component: MessageBroadcastIndex,
    meta: {
      permissions: ['administrator', IBSOFT_MESSAGE_BROADCAST_PERMISSION],
      hideCopilotLauncher: true,
    },
  },
];
