import { describe, expect, it } from 'vitest';

import { resolveNativeMessageSignature } from '../nativeSignature';

describe('#resolveNativeMessageSignature', () => {
  it('always suppresses the native footer signature', () => {
    expect(resolveNativeMessageSignature('Obrigado, Maria')).toBe('');
    expect(resolveNativeMessageSignature('')).toBe('');
  });
});
