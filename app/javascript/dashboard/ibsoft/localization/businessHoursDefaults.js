import {
  IBSOFT_DEFAULT_TIMEZONE,
  IBSOFT_DEFAULT_TIMEZONE_LABEL,
  ibsoftDefaultTimezoneOption,
} from './defaultTimezone';

export const IBSOFT_DEFAULT_BUSINESS_HOURS_TIMEZONE = IBSOFT_DEFAULT_TIMEZONE;

export const IBSOFT_DEFAULT_BUSINESS_HOURS_TIMEZONE_LABEL =
  IBSOFT_DEFAULT_TIMEZONE_LABEL;

export const IBSOFT_LEGACY_BUSINESS_HOURS_DEFAULT_TIMEZONES = [
  '',
  'UTC',
  'America/Los_Angeles',
];

export const ibsoftDefaultBusinessHoursTimezone = ibsoftDefaultTimezoneOption;

export const ibsoftBusinessHoursTimezoneOption = (timeZone, timeZones = []) => {
  if (IBSOFT_LEGACY_BUSINESS_HOURS_DEFAULT_TIMEZONES.includes(timeZone || '')) {
    return ibsoftDefaultBusinessHoursTimezone(timeZones);
  }

  return (
    timeZones.find(option => option.value === timeZone) ||
    ibsoftDefaultBusinessHoursTimezone(timeZones)
  );
};

export const ibsoftBusinessHoursDayNameKey = day =>
  `INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.${day}`;
