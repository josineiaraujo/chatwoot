<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import inboxMixin from 'shared/mixins/inboxMixin';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import BusinessDay from './BusinessDay.vue';
import {
  timeSlotParse,
  timeSlotTransform,
  defaultTimeSlot,
  timeZoneOptions,
} from '../helpers/businessHour';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import {
  ibsoftBusinessHoursDayNameKey,
  ibsoftBusinessHoursTimezoneOption,
  ibsoftDefaultBusinessHoursTimezone,
} from 'dashboard/ibsoft/localization/businessHoursDefaults';
import {
  parseWorkingHourBreaks,
  transformWorkingHourBreaks,
} from 'dashboard/ibsoft/localization/workingHourBreaks';

export default {
  components: {
    SettingsToggleSection,
    SettingsFieldSection,
    BusinessDay,
    NextButton,
    WootMessageEditor,
    ComboBox,
  },
  mixins: [inboxMixin],
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      isBusinessHoursEnabled: false,
      unavailableMessage: '',
      timeZone: ibsoftDefaultBusinessHoursTimezone(),
      dayNames: {
        0: ibsoftBusinessHoursDayNameKey(0),
        1: ibsoftBusinessHoursDayNameKey(1),
        2: ibsoftBusinessHoursDayNameKey(2),
        3: ibsoftBusinessHoursDayNameKey(3),
        4: ibsoftBusinessHoursDayNameKey(4),
        5: ibsoftBusinessHoursDayNameKey(5),
        6: ibsoftBusinessHoursDayNameKey(6),
      },
      timeSlots: [...defaultTimeSlot],
      workingHourBreaks: {},
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
    hasError() {
      if (!this.isBusinessHoursEnabled) return false;

      const hasInvalidWorkingHours = this.timeSlots.some(
        slot => slot.from && !slot.valid
      );
      const hasInvalidBreaks = Object.values(this.workingHourBreaks).some(
        breaks => breaks.some(workingHourBreak => !workingHourBreak.valid)
      );

      return hasInvalidWorkingHours || hasInvalidBreaks;
    },
    timeZones() {
      return [...timeZoneOptions()];
    },
    timeZoneValue: {
      get() {
        return ibsoftBusinessHoursTimezoneOption(
          this.timeZone?.value,
          this.timeZones
        ).value;
      },
      set(value) {
        const match = this.timeZones.find(tz => tz.value === value);
        if (match) this.timeZone = match;
      },
    },
    isRichEditorEnabled() {
      if (
        this.isATwilioChannel ||
        this.isATwitterInbox ||
        this.isAFacebookInbox
      )
        return false;
      return true;
    },
  },
  watch: {
    inbox() {
      this.setDefaults();
    },
  },
  mounted() {
    this.setDefaults();
  },
  methods: {
    setDefaults() {
      const {
        working_hours_enabled: isEnabled = false,
        out_of_office_message: unavailableMessage,
        working_hours: timeSlots = [],
        timezone: timeZone,
      } = this.inbox;
      const workingHourBreaks =
        this.inbox.ibsoft_working_hour_breaks ||
        this.inbox.ibsoftWorkingHourBreaks ||
        [];
      const slots = timeSlotParse(timeSlots).length
        ? timeSlotParse(timeSlots)
        : defaultTimeSlot;
      this.isBusinessHoursEnabled = isEnabled;
      this.unavailableMessage = unavailableMessage || '';
      this.timeSlots = slots;
      this.workingHourBreaks = parseWorkingHourBreaks(workingHourBreaks);
      this.timeZone = ibsoftBusinessHoursTimezoneOption(
        timeZone,
        this.timeZones
      );
    },
    onSlotUpdate(slotIndex, slotData) {
      this.timeSlots = this.timeSlots.map(item =>
        item.day === slotIndex ? slotData : item
      );
    },
    onBreaksUpdate(day, breaks) {
      this.workingHourBreaks = {
        ...this.workingHourBreaks,
        [day]: breaks,
      };
    },
    async updateInbox() {
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          working_hours_enabled: this.isBusinessHoursEnabled,
          out_of_office_message: this.unavailableMessage,
          working_hours: timeSlotTransform(this.timeSlots),
          ibsoft_working_hour_breaks: transformWorkingHourBreaks(
            this.workingHourBreaks
          ),
          timezone: this.timeZoneValue,
          channel: {},
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <div class="mx-6">
    <SettingsToggleSection
      v-model="isBusinessHoursEnabled"
      :header="$t('INBOX_MGMT.BUSINESS_HOURS.TOGGLE_AVAILABILITY')"
      :description="$t('INBOX_MGMT.BUSINESS_HOURS.TOGGLE_HELP')"
    >
      <template v-if="isBusinessHoursEnabled" #editor>
        <div class="mb-4">
          <WootMessageEditor
            v-if="isRichEditorEnabled"
            v-model="unavailableMessage"
            enable-variables
            is-format-mode
            :placeholder="
              $t('INBOX_MGMT.BUSINESS_HOURS.UNAVAILABLE_MESSAGE_LABEL')
            "
            :min-height="4"
          />
          <textarea v-else v-model="unavailableMessage" type="text" />
        </div>
      </template>
    </SettingsToggleSection>

    <div v-if="isBusinessHoursEnabled" class="flex items-center my-8 py-1">
      <div class="flex-1 h-px bg-n-weak" />
      <span class="text-body-main text-n-slate-11 px-2">
        {{ $t('INBOX_MGMT.BUSINESS_HOURS.WEEKLY_TITLE') }}
      </span>
      <div class="flex-1 h-px bg-n-weak" />
    </div>

    <SettingsFieldSection
      v-if="isBusinessHoursEnabled"
      :label="$t('INBOX_MGMT.BUSINESS_HOURS.TIMEZONE_LABEL')"
    >
      <ComboBox
        v-model="timeZoneValue"
        :options="timeZones"
        :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
        class="[&>div>button]:!bg-n-alpha-black2"
      />
    </SettingsFieldSection>

    <form class="flex flex-col" @submit.prevent="updateInbox">
      <div v-if="isBusinessHoursEnabled" class="mt-2">
        <div class="w-full">
          <table
            class="min-w-full table-auto outline outline-1 -outline-offset-1 outline-n-weak rounded-xl"
          >
            <thead>
              <tr class="border-b border-n-weak">
                <th
                  class="py-3 ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4 text-start text-heading-3 text-n-slate-12"
                >
                  {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.DAY') }}
                </th>
                <th
                  class="py-3 ltr:pr-3 rtl:pl-3 text-start text-heading-3 text-n-slate-12"
                >
                  {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.AVAILABILITY') }}
                </th>
                <th
                  class="py-3 ltr:pr-3 rtl:pl-3 text-start text-heading-3 text-n-slate-12"
                >
                  {{ $t('INBOX_MGMT.BUSINESS_HOURS.DAY.HOURS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <BusinessDay
                v-for="timeSlot in timeSlots"
                :key="timeSlot.day"
                :day-name="$t(dayNames[timeSlot.day])"
                :time-slot="timeSlot"
                :break-slots="workingHourBreaks[timeSlot.day] || []"
                @update="data => onSlotUpdate(timeSlot.day, data)"
                @update-breaks="data => onBreaksUpdate(timeSlot.day, data)"
              />
            </tbody>
          </table>
        </div>
      </div>
      <div class="w-full flex justify-end items-center py-4 mt-2">
        <NextButton
          type="submit"
          :label="$t('INBOX_MGMT.BUSINESS_HOURS.UPDATE')"
          :is-loading="uiFlags.isUpdating"
          :disabled="hasError"
        />
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
:deep(.message-editor) {
  @apply border-0;
}

textarea {
  @apply min-h-[4rem] mt-1.5;
}
</style>
