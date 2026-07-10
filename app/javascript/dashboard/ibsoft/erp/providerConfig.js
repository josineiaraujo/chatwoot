export const ERP_AUTH_FIELDS = Object.freeze({
  basic: ['username', 'password'],
  token_app: ['token', 'app'],
});

export const defaultAuthTypeForProvider = provider => {
  const authTypes = provider?.auth_types || [];
  return authTypes[0] || 'basic';
};

export const buildCredentialPayload = (authType, credentials = {}) => {
  const fields = ERP_AUTH_FIELDS[authType] || [];

  return fields.reduce((payload, field) => {
    const value = credentials[field];
    if (value) payload[field] = value;
    return payload;
  }, {});
};
