export const IXC_INSTANCE_TYPE = 'ixc';

export const isIxcContract = instanceType => instanceType === IXC_INSTANCE_TYPE;

export const issuedCredentialsFrom = payload => {
  if (payload?.credentials?.password) return payload.credentials;
  if (payload?.token) return { type: 'token', token: payload.token };

  return null;
};

export const buildPublicCurl = ({
  instanceType,
  endpointUrl,
  messagePayload,
  recipient,
  token,
  username,
  password,
}) => {
  if (isIxcContract(instanceType)) {
    return `curl --get '${endpointUrl}' \\
  --data-urlencode 'user=${username}' \\
  --data-urlencode 'pw=${password}' \\
  --data-urlencode 'dest=${recipient}' \\
  --data-urlencode 'text=${messagePayload}'`;
  }

  return `curl --get '${endpointUrl}' \\
  --data-urlencode 'msg=${messagePayload}' \\
  --data-urlencode 'to=${recipient}' \\
  --data-urlencode 'token=${token}'`;
};

export const buildOrderUpdateCurl = ({
  instanceType,
  endpointUrl,
  reference,
  status,
  recipient,
  token,
  username,
  password,
}) => {
  if (isIxcContract(instanceType)) {
    return `curl --get '${endpointUrl}' \\
  --data-urlencode 'user=${username}' \\
  --data-urlencode 'pw=${password}' \\
  --data-urlencode 'dest=${recipient}' \\
  --data-urlencode 'text=[fatura_id]=${reference}||[status]=${status}'`;
  }

  return `curl --get '${endpointUrl}' \\
  --data-urlencode 'fatura_id=${reference}' \\
  --data-urlencode 'status=${status}' \\
  --data-urlencode 'token=${token}'`;
};
