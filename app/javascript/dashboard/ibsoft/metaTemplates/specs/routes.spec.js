import { describe, expect, it } from 'vitest';

import { routes } from '../routes';

describe('meta template routes', () => {
  it('keeps every management route restricted to administrators', () => {
    expect(routes).toHaveLength(3);
    expect(routes.map(route => route.name)).toEqual([
      'ibsoft_meta_templates',
      'ibsoft_meta_templates_new',
      'ibsoft_meta_templates_edit',
    ]);
    expect(routes).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          meta: {
            permissions: ['administrator'],
            hideCopilotLauncher: true,
          },
        }),
      ])
    );
  });
});
