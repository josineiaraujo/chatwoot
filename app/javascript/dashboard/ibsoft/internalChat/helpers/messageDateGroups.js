export const normalizeIntlLocale = locale => {
  if (!locale) return undefined;

  return String(locale).replace('_', '-');
};

export const parseMessageDate = value => {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === 'number') {
    const timestamp = value < 1000000000000 ? value * 1000 : value;
    const date = new Date(timestamp);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const stringValue = String(value).trim();
  if (!stringValue) return null;

  if (/^\d+(\.\d+)?$/.test(stringValue)) {
    return parseMessageDate(Number(stringValue));
  }

  const date = new Date(stringValue);
  return Number.isNaN(date.getTime()) ? null : date;
};

export const localDateKey = value => {
  const date = parseMessageDate(value);
  if (!date) return '';

  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');

  return `${year}-${month}-${day}`;
};

export const isSameLocalDate = (left, right) => {
  const leftKey = localDateKey(left);
  const rightKey = localDateKey(right);

  return !!leftKey && leftKey === rightKey;
};

const capitalizeFirstLetter = value =>
  value ? value.charAt(0).toLocaleUpperCase() + value.slice(1) : '';

export const formatDateSeparator = (
  value,
  { locale, now = new Date(), todayLabel = 'Today' } = {}
) => {
  const date = parseMessageDate(value);
  if (!date) return '';
  if (isSameLocalDate(date, now)) return todayLabel;

  const formattedDate = new Intl.DateTimeFormat(normalizeIntlLocale(locale), {
    weekday: 'long',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);

  return capitalizeFirstLetter(formattedDate);
};

const formatDate = (date, locale) =>
  new Intl.DateTimeFormat(normalizeIntlLocale(locale), {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);

const formatTime = (date, locale) =>
  new Intl.DateTimeFormat(normalizeIntlLocale(locale), {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);

export const formatMessageTimestamp = (
  value,
  { locale, now = new Date() } = {}
) => {
  const date = parseMessageDate(value);
  if (!date) return '';

  const time = formatTime(date, locale);
  if (isSameLocalDate(date, now)) return time;

  return `${formatDate(date, locale)} ${time}`;
};

export const buildMessageDateGroups = (
  messages,
  { locale, now = new Date(), todayLabel = 'Today' } = {}
) => {
  return messages.reduce((groups, message, index) => {
    const key = localDateKey(message.created_at) || `unknown-${index}`;
    const previousGroup = groups[groups.length - 1];
    const item = { message, index };

    if (previousGroup?.key === key) {
      previousGroup.messages.push(item);
      return groups;
    }

    groups.push({
      key,
      label: formatDateSeparator(message.created_at, {
        locale,
        now,
        todayLabel,
      }),
      messages: [item],
    });

    return groups;
  }, []);
};
