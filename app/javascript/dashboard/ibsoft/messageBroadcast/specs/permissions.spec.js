import { describe, expect, it } from 'vitest';

import {
  IBSOFT_MESSAGE_BROADCAST_PERMISSION,
  canManageMessageBroadcast,
} from '../permissions';
import { routes } from '../routes';

describe('message broadcast permissions', () => {
  it('allows administrators and profiles with the module permission', () => {
    expect(canManageMessageBroadcast({ role: 'administrator' })).toBe(true);
    expect(
      canManageMessageBroadcast({
        role: 'agent',
        permissions: [IBSOFT_MESSAGE_BROADCAST_PERMISSION],
      })
    ).toBe(true);
  });

  it('blocks agents without the module permission', () => {
    expect(canManageMessageBroadcast({ role: 'agent', permissions: [] })).toBe(
      false
    );
    expect(canManageMessageBroadcast()).toBe(false);
  });

  it('protects the dashboard route with the same permission', () => {
    expect(routes[0].meta.permissions).toEqual([
      'administrator',
      IBSOFT_MESSAGE_BROADCAST_PERMISSION,
    ]);
  });
});
