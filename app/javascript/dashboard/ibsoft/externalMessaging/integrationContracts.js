export const STANDARD_INSTANCE_TYPE = 'standard';
export const IXC_INSTANCE_TYPE = 'ixc';

export const isStandardContract = instanceType =>
  instanceType === STANDARD_INSTANCE_TYPE;
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
  if (isStandardContract(instanceType)) {
    return `curl --request POST '${endpointUrl}' \\
  --header 'Authorization: Bearer ${token}' \\
  --header 'Content-Type: text/plain; charset=UTF-8' \\
  --data-raw '${messagePayload}||[to]=${recipient}'`;
  }

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
  if (isStandardContract(instanceType)) {
    return `curl --request POST '${endpointUrl}' \\
  --header 'Authorization: Bearer ${token}' \\
  --header 'Content-Type: text/plain; charset=UTF-8' \\
  --data-raw '[fatura_id]=${reference}||[status]=${status}'`;
  }

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
