export const IBSOFT_DEFAULT_TIMEZONE = 'America/Sao_Paulo';

export const IBSOFT_DEFAULT_TIMEZONE_LABEL = 'Brasilia (GMT-03:00)';

export const ibsoftDefaultTimezoneOption = (timeZones = []) =>
  timeZones.find(timeZone => timeZone.value === IBSOFT_DEFAULT_TIMEZONE) || {
    label: IBSOFT_DEFAULT_TIMEZONE_LABEL,
    value: IBSOFT_DEFAULT_TIMEZONE,
  };
