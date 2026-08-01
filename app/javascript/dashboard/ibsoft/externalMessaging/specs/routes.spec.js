import { describe, expect, it } from 'vitest';

import { routes } from '../routes';

describe('#externalMessagingRoutes', () => {
  it('restricts the management screen to administrators', () => {
    expect(routes).toHaveLength(1);
    expect(routes[0]).toMatchObject({
      name: 'ibsoft_external_messaging',
      meta: {
        permissions: ['administrator'],
        hideCopilotLauncher: true,
      },
    });
  });
});
