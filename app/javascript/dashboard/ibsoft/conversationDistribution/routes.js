import { frontendURL } from 'dashboard/helper/URLHelper';
import SupervisorDashboard from './views/SupervisorDashboard.vue';
import EventLogsDashboard from './views/EventLogsDashboard.vue';

export const IBSOFT_DISTRIBUTION_SUPERVISOR_PERMISSION =
  'ibsoft_conversation_distribution_supervise';

export const routes = [
  {
    path: frontendURL(
      'accounts/:accountId/conversation-distribution/supervisor'
    ),
    name: 'ibsoft_conversation_distribution_supervisor',
    component: SupervisorDashboard,
    meta: {
      permissions: ['administrator', IBSOFT_DISTRIBUTION_SUPERVISOR_PERMISSION],
      hideCopilotLauncher: true,
    },
  },
  {
    path: frontendURL('accounts/:accountId/conversation-distribution/events'),
    name: 'ibsoft_conversation_distribution_event_logs',
    component: EventLogsDashboard,
    meta: {
      permissions: ['administrator', IBSOFT_DISTRIBUTION_SUPERVISOR_PERMISSION],
      hideCopilotLauncher: true,
    },
  },
];
