export const IBSOFT_CONVERSATION_PROTOCOL_ATTRIBUTE = 'ibsoft_protocol';

const padDatePart = value => String(value).padStart(2, '0');

const normalizeTimestamp = timestamp => {
  const numericTimestamp = Number(timestamp);

  if (!Number.isFinite(numericTimestamp) || numericTimestamp <= 0) {
    return null;
  }

  return numericTimestamp > 10000000000
    ? numericTimestamp
    : numericTimestamp * 1000;
};

export const buildConversationProtocol = ({
  createdAt,
  accountId,
  conversationId,
}) => {
  const timestamp = normalizeTimestamp(createdAt);

  if (!timestamp || !accountId || !conversationId) {
    return '';
  }

  const date = new Date(timestamp);
  const year = date.getUTCFullYear();
  const month = padDatePart(date.getUTCMonth() + 1);
  const day = padDatePart(date.getUTCDate());

  return `${year}${month}${day}-${accountId}-${conversationId}`;
};

export const parseConversationProtocol = protocol => {
  const normalizedProtocol = String(protocol || '').trim();
  const match = normalizedProtocol.match(/^(\d{4})(\d{2})(\d{2})-(\d+)-(\d+)$/);

  if (!match) {
    return null;
  }

  const [, year, month, day, accountId, conversationId] = match;
  const isoDate = `${year}-${month}-${day}`;
  const date = new Date(`${isoDate}T00:00:00.000Z`);

  if (
    Number.isNaN(date.getTime()) ||
    date.getUTCFullYear() !== Number(year) ||
    date.getUTCMonth() + 1 !== Number(month) ||
    date.getUTCDate() !== Number(day)
  ) {
    return null;
  }

  return {
    date: isoDate,
    accountId: Number(accountId),
    conversationId: Number(conversationId),
  };
};
