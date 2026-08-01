import { describe, expect, it } from 'vitest';

import {
  buildOrderUpdateCurl,
  buildPublicCurl,
  isIxcContract,
  issuedCredentialsFrom,
} from '../integrationContracts';

describe('external messaging integration contracts', () => {
  it('builds the existing SGP contract without changing its envelope', () => {
    const command = buildPublicCurl({
      instanceType: 'sgp_generic',
      endpointUrl: 'https://example.test/chathub-sender/sgp/generico/',
      messagePayload: '[template_name]=aviso',
      recipient: '5575982479788',
      token: 'ibext_secret',
    });

    expect(command).toContain("--data-urlencode 'msg=[template_name]=aviso'");
    expect(command).toContain("--data-urlencode 'to=5575982479788'");
    expect(command).toContain("--data-urlencode 'token=ibext_secret'");
    expect(command).not.toContain("--data-urlencode 'user=");
  });

  it('builds the exact IXC user, pw, dest, and text envelope', () => {
    const command = buildPublicCurl({
      instanceType: 'ixc',
      endpointUrl: 'https://example.test/chathub-sender/ixc/',
      messagePayload: '[template_name]=aviso||[body.nome]=Maria',
      recipient: '5575982479788',
      username: 'ixc_42',
      password: 'ibext_secret',
    });

    expect(isIxcContract('ixc')).toBe(true);
    expect(command).toContain("--data-urlencode 'user=ixc_42'");
    expect(command).toContain("--data-urlencode 'pw=ibext_secret'");
    expect(command).toContain("--data-urlencode 'dest=5575982479788'");
    expect(command).toContain(
      "--data-urlencode 'text=[template_name]=aviso||[body.nome]=Maria'"
    );
    expect(command).not.toContain("--data-urlencode 'token=");
  });

  it('normalizes one-time credentials without inventing persisted secrets', () => {
    expect(issuedCredentialsFrom({ token: 'sgp-secret' })).toEqual({
      type: 'token',
      token: 'sgp-secret',
    });
    expect(
      issuedCredentialsFrom({
        credentials: {
          type: 'username_password',
          username: 'ixc_9',
          password: 'ixc-secret',
        },
      })
    ).toEqual({
      type: 'username_password',
      username: 'ixc_9',
      password: 'ixc-secret',
    });
    expect(issuedCredentialsFrom({})).toBeNull();
  });

  it('builds family-specific order update authentication without changing its fields', () => {
    const sgp = buildOrderUpdateCurl({
      instanceType: 'sgp_generic',
      endpointUrl: 'https://example.test/chathub-sender/sgp/pedido/',
      reference: '9388',
      status: 'pago',
      token: 'sgp-secret',
    });
    const ixc = buildOrderUpdateCurl({
      instanceType: 'ixc',
      endpointUrl: 'https://example.test/chathub-sender/ixc/pedido/',
      reference: '9388',
      status: 'pago',
      recipient: '5575982479788',
      username: 'ixc_42',
      password: 'ixc-secret',
    });

    expect(sgp).toContain("--data-urlencode 'fatura_id=9388'");
    expect(sgp).toContain("--data-urlencode 'token=sgp-secret'");
    expect(ixc).toContain("--data-urlencode 'user=ixc_42'");
    expect(ixc).toContain("--data-urlencode 'pw=ixc-secret'");
    expect(ixc).toContain("--data-urlencode 'dest=5575982479788'");
    expect(ixc).toContain(
      "--data-urlencode 'text=[fatura_id]=9388||[status]=pago'"
    );
    expect(ixc).not.toContain("--data-urlencode 'fatura_id=9388'");
    expect(ixc).not.toContain("--data-urlencode 'token=");
  });
});
