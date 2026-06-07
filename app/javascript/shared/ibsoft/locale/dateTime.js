import { format, formatDistanceToNow, fromUnixTime } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const DEFAULT_LOCALE = 'en';

const DATE_FNS_LOCALES = {
  pt: ptBR,
  pt_BR: ptBR,
  'pt-BR': ptBR,
};

const PORTUGUESE_DATE_FORMATS = {
  'h:mm a': 'HH:mm',
  'hh:mm a': 'HH:mm',
  'LLL d, h:mm a': 'd MMM, HH:mm',
  'LLL d yyyy, h:mm a': 'd MMM yyyy, HH:mm',
  'LLL d, yyyy': 'd MMM yyyy',
  'LLL d, yyyy hh:mm a': 'd MMM yyyy, HH:mm',
  'LLL d y, h:mm a': 'd MMM y, HH:mm',
  'h.mmaaa': 'HH:mm',
  'd MMM yyyy, h.mmaaa': 'd MMM yyyy, HH:mm',
  'd MMM, h.mmaaa': 'd MMM, HH:mm',
  'EEE, d MMM, h:mm a': 'EEE, d MMM, HH:mm',
  'EEE, d MMM yyyy, h:mm a': 'EEE, d MMM yyyy, HH:mm',
  "EEE, MMM d, yyyy 'at' p": "EEE, d MMM yyyy '\u00e0s' HH:mm",
  'MMM d, yyyy': 'd MMM yyyy',
  'MMM d': 'd MMM',
  'MMM dd, yyyy': 'dd MMM yyyy',
  'dd MMM, yyyy': 'dd MMM yyyy',
  'MMM dd, yyyy, hh:mm a': 'dd MMM yyyy, HH:mm',
};

const normalizeLocaleCode = locale =>
  typeof locale === 'string' && locale.trim()
    ? locale.trim().replace('-', '_')
    : DEFAULT_LOCALE;

export const setIbsoftCurrentLocale = locale => {
  if (typeof window === 'undefined' || !locale) return;
  window.chatwootConfig = {
    ...(window.chatwootConfig || {}),
    selectedLocale: locale,
  };
};

export const getIbsoftCurrentLocale = () => {
  if (typeof window === 'undefined') return DEFAULT_LOCALE;

  return normalizeLocaleCode(
    window.WOOT_WIDGET?.$root?.$i18n?.locale ||
      window.chatwootConfig?.selectedLocale ||
      document?.documentElement?.lang
  );
};

const isPortugueseLocale = locale =>
  normalizeLocaleCode(locale).startsWith('pt');

const getDateFnsLocale = locale => DATE_FNS_LOCALES[locale] || undefined;

export const ibsoftToDate = time => {
  if (time instanceof Date) return time;

  const numericTime = Number(time);
  if (!Number.isNaN(numericTime)) {
    return numericTime > 9999999999
      ? new Date(numericTime)
      : fromUnixTime(numericTime);
  }

  return new Date(time);
};

const localizeDateFormat = (dateFormat, locale) => {
  if (!isPortugueseLocale(locale)) return dateFormat;
  return PORTUGUESE_DATE_FORMATS[dateFormat] || dateFormat;
};

export const ibsoftFormatDate = (time, dateFormat) => {
  const locale = getIbsoftCurrentLocale();
  const dateFnsLocale = getDateFnsLocale(locale);
  return format(ibsoftToDate(time), localizeDateFormat(dateFormat, locale), {
    ...(dateFnsLocale ? { locale: dateFnsLocale } : {}),
  });
};

export const ibsoftFormatDistanceToNow = time => {
  const locale = getIbsoftCurrentLocale();
  const dateFnsLocale = getDateFnsLocale(locale);
  return formatDistanceToNow(ibsoftToDate(time), {
    addSuffix: true,
    ...(dateFnsLocale ? { locale: dateFnsLocale } : {}),
  });
};

const stripAccents = text =>
  text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

const normalizeRelativeText = text =>
  stripAccents(String(text || '').toLowerCase())
    .replace(/\s+/g, ' ')
    .trim();

const UNIT_ALIASES = {
  m: 'minute',
  min: 'minute',
  minute: 'minute',
  minutes: 'minute',
  minuto: 'minute',
  minutos: 'minute',
  h: 'hour',
  hour: 'hour',
  hours: 'hour',
  hora: 'hour',
  horas: 'hour',
  d: 'day',
  day: 'day',
  days: 'day',
  dia: 'day',
  dias: 'day',
  mo: 'month',
  month: 'month',
  months: 'month',
  mes: 'month',
  meses: 'month',
  y: 'year',
  year: 'year',
  years: 'year',
  ano: 'year',
  anos: 'year',
};

const EN_SHORT_UNITS = {
  minute: 'm',
  hour: 'h',
  day: 'd',
  month: 'mo',
  year: 'y',
};

const PT_SHORT_UNITS = {
  minute: value => `${value} min`,
  hour: value => `${value} h`,
  day: value => `${value} d`,
  month: value => `${value} ${Number(value) === 1 ? 'm\u00eas' : 'meses'}`,
  year: value => `${value} ${Number(value) === 1 ? 'ano' : 'anos'}`,
};

const parseRelativeToken = token => {
  const normalizedToken = normalizeRelativeText(token)
    .replace(/^(in|ha)\s+/i, '')
    .replace(/\s+(ago|atras)$/i, '')
    .replace(/^(about|over|almost|cerca de|cerca)\s+/i, '')
    .trim();

  if (
    normalizedToken.includes('less than a minute') ||
    normalizedToken.includes('menos de um minuto') ||
    normalizedToken.includes('menos de 1 minuto')
  ) {
    return { now: true };
  }

  const singleValueMap = {
    'a minute': { value: 1, unit: 'minute' },
    'an hour': { value: 1, unit: 'hour' },
    'a day': { value: 1, unit: 'day' },
    'a month': { value: 1, unit: 'month' },
    'a year': { value: 1, unit: 'year' },
    'um minuto': { value: 1, unit: 'minute' },
    'uma hora': { value: 1, unit: 'hour' },
    'um dia': { value: 1, unit: 'day' },
    'um mes': { value: 1, unit: 'month' },
    'um ano': { value: 1, unit: 'year' },
  };

  if (singleValueMap[normalizedToken]) return singleValueMap[normalizedToken];

  const match = normalizedToken.match(
    /^(\d+(?:[.,]\d+)?)\s*(m|min|minute|minutes|minuto|minutos|h|hour|hours|hora|horas|d|day|days|dia|dias|mo|month|months|mes|meses|y|year|years|ano|anos)$/i
  );
  if (!match) return null;

  const value = match[1].replace(',', '.');
  const unit = UNIT_ALIASES[match[2].toLowerCase()];
  return unit ? { value, unit } : null;
};

const formatCompactRelative = ({ value, unit }, withAgo, locale) => {
  if (isPortugueseLocale(locale)) {
    const formatter = PT_SHORT_UNITS[unit];
    const compactValue = formatter ? formatter(value) : `${value} ${unit}`;
    return withAgo ? `h\u00e1 ${compactValue}` : compactValue;
  }

  const compactValue = `${value}${EN_SHORT_UNITS[unit] || unit}`;
  return withAgo ? `${compactValue} ago` : compactValue;
};

export const ibsoftShortTimestamp = (time, withAgo = false) => {
  const locale = getIbsoftCurrentLocale();
  const normalizedTime = normalizeRelativeText(time);
  if (
    !normalizedTime ||
    normalizedTime === 'now' ||
    normalizedTime === 'agora'
  ) {
    return isPortugueseLocale(locale) ? 'agora' : 'now';
  }

  const tokens = normalizedTime.split(/\s*,\s*/);
  const convertedTokens = tokens.map(token => {
    const parsed = parseRelativeToken(token);
    if (!parsed) return token;
    if (parsed.now) return isPortugueseLocale(locale) ? 'agora' : 'now';
    return formatCompactRelative(parsed, withAgo, locale);
  });

  return convertedTokens.join(', ');
};
