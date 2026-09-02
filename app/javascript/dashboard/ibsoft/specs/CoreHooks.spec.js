import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const readSource = relativePath =>
  readFileSync(new URL(relativePath, import.meta.url), 'utf8');

describe('Ibsoft core connection points', () => {
  it('registers every private route collection in the dashboard router', () => {
    const source = readSource('../../routes/dashboard/dashboard.routes.js');
    const routeModules = [
      'dashboard/ibsoft/internalChat/routes',
      'dashboard/ibsoft/conversationDistribution/routes',
      'dashboard/ibsoft/chathubSettings/routes',
      'dashboard/ibsoft/chathubAnalytics/routes',
      'dashboard/ibsoft/messageBroadcast/routes',
      'dashboard/ibsoft/externalMessaging/routes',
    ];

    routeModules.forEach(routeModule => {
      expect(source).toContain(`from '${routeModule}'`);
    });
  });

  it('keeps the dashboard locale synchronized with private formatters', () => {
    const source = readSource('../../App.vue');

    expect(source).toContain(
      "import { setIbsoftCurrentLocale } from 'shared/ibsoft/locale/dateTime'"
    );
    expect(source).toContain('setIbsoftCurrentLocale(locale)');
  });
});
