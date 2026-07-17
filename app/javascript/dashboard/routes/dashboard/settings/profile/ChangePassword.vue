<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      currentPassword: '',
      password: '',
      passwordConfirmation: '',
      passwordVisibility: {
        current: false,
        new: false,
        confirmation: false,
      },
      isPasswordChanging: false,
      errorMessage: '',
      inputStyles: {
        borderRadius: '0.75rem',
        padding: '0.375rem 0.75rem',
        fontSize: '0.875rem',
        marginBottom: '0.125rem',
      },
    };
  },
  validations: {
    currentPassword: {
      required,
    },
    password: {
      minLength: minLength(6),
    },
    passwordConfirmation: {
      minLength: minLength(6),
      isEqPassword(value) {
        if (value !== this.password) {
          return false;
        }
        return true;
      },
    },
  },
  computed: {
    isButtonDisabled() {
      return (
        !this.currentPassword ||
        !this.passwordConfirmation ||
        !this.v$.passwordConfirmation.isEqPassword
      );
    },
  },
  methods: {
    togglePasswordVisibility(field) {
      this.passwordVisibility[field] = !this.passwordVisibility[field];
    },
    passwordInputType(field) {
      return this.passwordVisibility[field] ? 'text' : 'password';
    },
    passwordToggleIcon(field) {
      return this.passwordVisibility[field]
        ? 'i-lucide-eye-off'
        : 'i-lucide-eye';
    },
    passwordToggleLabel(field) {
      if (this.passwordVisibility[field]) {
        return this.$t('PROFILE_SETTINGS.FORM.PASSWORD_SECTION.HIDE_PASSWORD');
      }
      return this.$t('PROFILE_SETTINGS.FORM.PASSWORD_SECTION.SHOW_PASSWORD');
    },
    async changePassword() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        useAlert(this.$t('PROFILE_SETTINGS.FORM.ERROR'));
        return;
      }
      let alertMessage = this.$t('PROFILE_SETTINGS.PASSWORD_UPDATE_SUCCESS');
      try {
        await this.$store.dispatch('updatePassword', {
          password: this.password,
          passwordConfirmation: this.passwordConfirmation,
          currentPassword: this.currentPassword,
        });
      } catch (error) {
        alertMessage =
          parseAPIErrorResponse(error) ||
          this.$t('RESET_PASSWORD.API.ERROR_MESSAGE');
      } finally {
        useAlert(alertMessage);
      }
    },
  },
};
</script>

<template>
  <form @submit.prevent="changePassword()">
    <div class="flex flex-col w-full gap-4">
      <div class="relative">
        <woot-input
          v-model="currentPassword"
          :type="passwordInputType('current')"
          :styles="inputStyles"
          class="ltr:[&>input]:!pr-10 rtl:[&>input]:!pl-10"
          :class="{ error: v$.currentPassword.$error }"
          :label="$t('PROFILE_SETTINGS.FORM.CURRENT_PASSWORD.LABEL')"
          :placeholder="
            $t('PROFILE_SETTINGS.FORM.CURRENT_PASSWORD.PLACEHOLDER')
          "
          :error="`${
            v$.currentPassword.$error
              ? $t('PROFILE_SETTINGS.FORM.CURRENT_PASSWORD.ERROR')
              : ''
          }`"
          @input="v$.currentPassword.$touch"
          @blur="v$.currentPassword.$touch"
        />
        <NextButton
          v-tooltip.top="passwordToggleLabel('current')"
          data-testid="toggle-current-password"
          type="button"
          xs
          slate
          ghost
          no-animation
          class="!absolute top-6 z-10 ltr:right-1 rtl:left-1"
          :aria-label="passwordToggleLabel('current')"
          :aria-pressed="passwordVisibility.current"
          :icon="passwordToggleIcon('current')"
          @click="togglePasswordVisibility('current')"
        />
      </div>

      <div class="relative">
        <woot-input
          v-model="password"
          :type="passwordInputType('new')"
          :styles="inputStyles"
          class="ltr:[&>input]:!pr-10 rtl:[&>input]:!pl-10"
          :class="{ error: v$.password.$error }"
          :label="$t('PROFILE_SETTINGS.FORM.PASSWORD.LABEL')"
          :placeholder="$t('PROFILE_SETTINGS.FORM.PASSWORD.PLACEHOLDER')"
          :error="`${
            v$.password.$error ? $t('PROFILE_SETTINGS.FORM.PASSWORD.ERROR') : ''
          }`"
          @input="v$.password.$touch"
          @blur="v$.password.$touch"
        />
        <NextButton
          v-tooltip.top="passwordToggleLabel('new')"
          data-testid="toggle-new-password"
          type="button"
          xs
          slate
          ghost
          no-animation
          class="!absolute top-6 z-10 ltr:right-1 rtl:left-1"
          :aria-label="passwordToggleLabel('new')"
          :aria-pressed="passwordVisibility.new"
          :icon="passwordToggleIcon('new')"
          @click="togglePasswordVisibility('new')"
        />
      </div>

      <div class="relative">
        <woot-input
          v-model="passwordConfirmation"
          :type="passwordInputType('confirmation')"
          :styles="inputStyles"
          class="ltr:[&>input]:!pr-10 rtl:[&>input]:!pl-10"
          :class="{ error: v$.passwordConfirmation.$error }"
          :label="$t('PROFILE_SETTINGS.FORM.PASSWORD_CONFIRMATION.LABEL')"
          :placeholder="
            $t('PROFILE_SETTINGS.FORM.PASSWORD_CONFIRMATION.PLACEHOLDER')
          "
          :error="`${
            v$.passwordConfirmation.$error
              ? $t('PROFILE_SETTINGS.FORM.PASSWORD_CONFIRMATION.ERROR')
              : ''
          }`"
          @input="v$.passwordConfirmation.$touch"
          @blur="v$.passwordConfirmation.$touch"
        />
        <NextButton
          v-tooltip.top="passwordToggleLabel('confirmation')"
          data-testid="toggle-password-confirmation"
          type="button"
          xs
          slate
          ghost
          no-animation
          class="!absolute top-6 z-10 ltr:right-1 rtl:left-1"
          :aria-label="passwordToggleLabel('confirmation')"
          :aria-pressed="passwordVisibility.confirmation"
          :icon="passwordToggleIcon('confirmation')"
          @click="togglePasswordVisibility('confirmation')"
        />
      </div>

      <div>
        <NextButton
          type="submit"
          :label="$t('PROFILE_SETTINGS.FORM.PASSWORD_SECTION.BTN_TEXT')"
          :disabled="isButtonDisabled"
        />
      </div>
    </div>
  </form>
</template>
