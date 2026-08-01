import { frontendURL } from 'dashboard/helper/URLHelper';
import MetaTemplatesIndex from './views/Index.vue';

const baseRoute = {
  component: MetaTemplatesIndex,
  meta: {
    permissions: ['administrator'],
    hideCopilotLauncher: true,
  },
};

export const routes = [
  {
    ...baseRoute,
    path: frontendURL('accounts/:accountId/meta-templates/:inboxId'),
    name: 'ibsoft_meta_templates',
  },
  {
    ...baseRoute,
    path: frontendURL('accounts/:accountId/meta-templates/:inboxId/new'),
    name: 'ibsoft_meta_templates_new',
  },
  {
    ...baseRoute,
    path: frontendURL(
      'accounts/:accountId/meta-templates/:inboxId/:templateId/edit'
    ),
    name: 'ibsoft_meta_templates_edit',
  },
];
