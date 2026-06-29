const isPlainObject = value =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

export const mergeLocaleWithOverrides = (base, overrides) => {
  const result = { ...base };

  Object.entries(overrides).forEach(([key, value]) => {
    if (isPlainObject(value) && isPlainObject(result[key])) {
      result[key] = mergeLocaleWithOverrides(result[key], value);
      return;
    }

    result[key] = value;
  });

  return result;
};
