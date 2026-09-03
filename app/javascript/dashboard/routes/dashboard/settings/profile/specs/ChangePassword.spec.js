import { mount } from '@vue/test-utils';

import enTheme from 'dashboard/i18n/locale/en/ibsoftTheme.json';
import ptBrTheme from 'dashboard/i18n/locale/pt_BR/ibsoftTheme.json';
import ptBrSettings from 'dashboard/i18n/locale/pt_BR/settings.json';
import { mergeLocaleWithOverrides } from 'dashboard/ibsoft/i18n/mergeLocale';
import ChangePassword from '../ChangePassword.vue';

const translateFromEnglishTheme = key =>
  key.split('.').reduce((value, segment) => value?.[segment], enTheme) ?? key;

const WootInputStub = {
  name: 'WootInput',
  props: {
    label: { type: String, default: '' },
    modelValue: { type: String, default: '' },
    type: { type: String, default: 'text' },
  },
  emits: ['update:modelValue', 'input', 'blur'],
  template: `
    <label>
      <span>{{ label }}</span>
      <input
        :value="modelValue"
        :type="type"
        @input="$emit('update:modelValue', $event.target.value)"
        @blur="$emit('blur', $event.target.value)"
      />
    </label>
  `,
};

const mountComponent = () =>
  mount(ChangePassword, {
    global: {
      components: {
        WootInput: WootInputStub,
      },
      mocks: {
        $t: translateFromEnglishTheme,
      },
    },
  });

describe('ChangePassword', () => {
  it('reveals each password field independently', async () => {
    const wrapper = mountComponent();
    const inputs = wrapper.findAll('input');

    expect(inputs.map(input => input.attributes('type'))).toEqual([
      'password',
      'password',
      'password',
    ]);

    await wrapper
      .get('[data-testid="toggle-current-password"]')
      .trigger('click');

    expect(inputs.map(input => input.attributes('type'))).toEqual([
      'text',
      'password',
      'password',
    ]);

    await wrapper.get('[data-testid="toggle-new-password"]').trigger('click');
    await wrapper
      .get('[data-testid="toggle-password-confirmation"]')
      .trigger('click');

    expect(inputs.map(input => input.attributes('type'))).toEqual([
      'text',
      'text',
      'text',
    ]);
  });

  it('updates the accessible action when password visibility changes', async () => {
    const wrapper = mountComponent();
    const toggle = wrapper.get('[data-testid="toggle-current-password"]');

    expect(toggle.attributes('aria-label')).toBe(
      enTheme.PROFILE_SETTINGS.FORM.PASSWORD_SECTION.SHOW_PASSWORD
    );
    expect(toggle.attributes('aria-pressed')).toBe('false');

    await toggle.trigger('click');

    expect(toggle.attributes('aria-label')).toBe(
      enTheme.PROFILE_SETTINGS.FORM.PASSWORD_SECTION.HIDE_PASSWORD
    );
    expect(toggle.attributes('aria-pressed')).toBe('true');
  });

  it('provides complete Brazilian Portuguese active-session translations', () => {
    const localizedSettings = mergeLocaleWithOverrides(ptBrSettings, ptBrTheme);

    expect(localizedSettings.PROFILE_SETTINGS.FORM.SESSIONS_SECTION).toEqual({
      TITLE: 'Sessões ativas',
      NOTE: 'Estes são os dispositivos conectados à sua conta no momento.',
      CURRENT: 'Sessão atual',
      REVOKE: 'Revogar',
      REVOKE_SUCCESS: 'Sessão revogada com sucesso',
      REVOKE_ERROR: 'Não foi possível revogar a sessão. Tente novamente.',
      FETCH_ERROR: 'Não foi possível carregar as sessões. Tente novamente.',
      LAST_ACTIVE: 'Última atividade',
      UNKNOWN_DEVICE: 'Dispositivo desconhecido',
    });
  });
});
