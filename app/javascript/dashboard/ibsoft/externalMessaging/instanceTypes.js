import ixcDarkLogo from '../assets/images/logo/ixc/dark.png';
import ixcLightLogo from '../assets/images/logo/ixc/light.png';
import sgpDarkLogo from '../assets/images/logo/sgp/dark.png';
import sgpLightLogo from '../assets/images/logo/sgp/light.png';

export const DEFAULT_INSTANCE_TYPE = 'sgp_generic';

export const INSTANCE_TYPES = Object.freeze([
  Object.freeze({
    value: DEFAULT_INSTANCE_TYPE,
    icon: 'i-lucide-braces',
    logo: Object.freeze({
      light: sgpLightLogo,
      dark: sgpDarkLogo,
    }),
    label: t => t('IBSOFT_EXTERNAL_MESSAGING.TYPES.SGP_GENERIC.NAME'),
    description: t =>
      t('IBSOFT_EXTERNAL_MESSAGING.TYPES.SGP_GENERIC.DESCRIPTION'),
  }),
  Object.freeze({
    value: 'ixc',
    icon: 'i-lucide-waypoints',
    logo: Object.freeze({
      light: ixcLightLogo,
      dark: ixcDarkLogo,
    }),
    label: t => t('IBSOFT_EXTERNAL_MESSAGING.TYPES.IXC.NAME'),
    description: t => t('IBSOFT_EXTERNAL_MESSAGING.TYPES.IXC.DESCRIPTION'),
  }),
]);

export const findInstanceType = instanceType =>
  INSTANCE_TYPES.find(type => type.value === instanceType) || INSTANCE_TYPES[0];

export const translatedInstanceTypes = t =>
  INSTANCE_TYPES.map(type => ({
    ...type,
    label: type.label(t),
    description: type.description(t),
  }));
