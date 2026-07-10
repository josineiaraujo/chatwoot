import { describe, expect, it } from 'vitest';

import {
  buildCredentialPayload,
  defaultAuthTypeForProvider,
} from '../providerConfig';

describe('#providerConfig', () => {
  it('uses the first provider auth type as the default option', () => {
    expect(
      defaultAuthTypeForProvider({ auth_types: ['token_app', 'basic'] })
    ).toBe('token_app');
  });

  it('keeps only credentials required by the selected auth type', () => {
    expect(
      buildCredentialPayload('token_app', {
        username: 'ignored',
        token: 'token',
        app: 'app',
      })
    ).toEqual({
      token: 'token',
      app: 'app',
    });
  });

  it('omits blank values so editing can preserve existing secrets', () => {
    expect(
      buildCredentialPayload('basic', {
        username: '',
        password: 'new-password',
      })
    ).toEqual({
      password: 'new-password',
    });
  });
});
