<script>
import differenceInMinutes from 'date-fns/differenceInMinutes';
import parse from 'date-fns/parse';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextSelect from 'dashboard/components-next/select/Select.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { generateTimeSlots } from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';
import {
  defaultWorkingHourBreak,
  isValidWorkingHourBreak,
} from 'dashboard/ibsoft/localization/workingHourBreaks';

const timeSlots = generateTimeSlots(30);

const groupByPeriod = slots =>
  ['AM', 'PM']
    .map(period => ({
      label: period,
      options: slots
        .filter(slot => slot.endsWith(period))
        .map(slot => ({ value: slot, label: slot })),
    }))
    .filter(group => group.options.length);

export default {
  components: {
    Icon,
    NextSelect,
    ToggleSwitch,
  },
  props: {
    dayName: {
      type: String,
      required: true,
    },
    timeSlot: {
      type: Object,
      default: () => ({
        day: 0,
        from: '',
        to: '',
        valid: false,
        openAllDay: false,
      }),
    },
    breakSlots: {
      type: Array,
      default: () => [],
    },
  },
  emits: ['update', 'updateBreaks'],
  computed: {
    fromTimeSlots() {
      return groupByPeriod(timeSlots);
    },
    toTimeSlots() {
      return groupByPeriod(timeSlots.filter(slot => slot !== '12:00 AM'));
    },
    isDayEnabled: {
      get() {
        return Boolean(this.timeSlot.from && this.timeSlot.to);
      },
      set(value) {
        this.$emit(
          'update',
          value
            ? {
                ...this.timeSlot,
                from: '09:00 AM',
                to: '05:00 PM',
                valid: true,
                openAllDay: false,
              }
            : {
                ...this.timeSlot,
                from: '',
                to: '',
                valid: false,
                openAllDay: false,
              }
        );
      },
    },
    fromTime: {
      get() {
        return this.timeSlot.from;
      },
      set(value) {
        const fromDate = parse(value, 'hh:mm a', new Date());
        const valid = differenceInMinutes(this.toDate, fromDate) > 0;
        this.$emit('update', {
          ...this.timeSlot,
          from: value,
          valid,
        });
      },
    },
    toTime: {
      get() {
        return this.timeSlot.to;
      },
      set(value) {
        const toDate = parse(value, 'hh:mm a', new Date());
        const valid =
          value === '12:00 AM' ||
          differenceInMinutes(toDate, this.fromDate) > 0;
        this.$emit('update', {
          ...this.timeSlot,
          to: value,
          valid,
        });
      },
    },
    fromDate() {
      return parse(this.fromTime, 'hh:mm a', new Date());
    },
    toDate() {
      return parse(this.toTime, 'hh:mm a', new Date());
    },
    isOpenAllDay: {
      get() {
        return this.timeSlot.openAllDay;
      },
      set(value) {
        this.$emit(
          'update',
          value
            ? {
                ...this.timeSlot,
                from: '12:00 AM',
                to: '11:59 PM',
                valid: true,
                openAllDay: true,
              }
            : {
                ...this.timeSlot,
                from: '09:00 AM',
                to: '05:00 PM',
                valid: true,
                openAllDay: false,
              }
        );
      },
    },
  },
  methods: {
    addBreak() {
      this.$emit('updateBreaks', [
        ...this.breakSlots,
        { ...defaultWorkingHourBreak },
      ]);
    },
    removeBreak(index) {
      this.$emit(
        'updateBreaks',
        this.breakSlots.filter((_, breakIndex) => breakIndex !== index)
      );
    },
    updateBreak(index, key, value) {
      const nextBreaks = this.breakSlots.map((item, breakIndex) => {
        if (breakIndex !== index) return item;

        const updated = {
          ...item,
          [key]: value,
        };

        return {
          ...updated,
          valid: isValidWorkingHourBreak(updated),
        };
      });

      this.$emit('updateBreaks', nextBreaks);
    },
  },
};
</script>

<template>
  <tr>
    <td class="ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4">
      <div class="flex min-h-16 items-center gap-2">
        <ToggleSwitch
          v-model="isDayEnabled"
          name="enable-policy-day"
          :title="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.ENABLE')"
        />
        <span class="text-body-main font-medium text-n-slate-12">
          {{ dayName }}
        </span>
      </div>
    </td>

    <td class="py-3 ltr:pr-3 rtl:pl-3">
      <div v-if="isDayEnabled" class="flex flex-col gap-3">
        <div class="flex flex-wrap items-center gap-4">
          <div class="flex items-center gap-2">
            <ToggleSwitch
              v-model="isOpenAllDay"
              name="enable-policy-open-all-day"
              :title="$t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY')"
            />
            <span class="text-body-main text-n-slate-12">
              {{ $t('INBOX_MGMT.BUSINESS_HOURS.ALL_DAY') }}
            </span>
          </div>
          <template v-if="!isOpenAllDay">
            <NextSelect
              v-model="fromTime"
              :groups="fromTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            />
            <Icon icon="i-lucide-minus size-4 text-n-slate-11" />
            <NextSelect
              v-model="toTime"
              :groups="toTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.DAY.CHOOSE')"
            />
          </template>
        </div>

        <div class="grid gap-2">
          <div class="flex items-center justify-between gap-3">
            <span class="text-label-small text-n-slate-11">
              {{ $t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.LABEL') }}
            </span>
            <button
              type="button"
              class="inline-flex items-center gap-1 text-label-small text-n-brand hover:text-n-brand"
              @click="addBreak"
            >
              <Icon icon="i-lucide-plus size-3.5" />
              {{ $t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.ADD') }}
            </button>
          </div>

          <div
            v-for="(breakSlot, index) in breakSlots"
            :key="index"
            class="flex flex-wrap items-center gap-2"
          >
            <NextSelect
              :model-value="breakSlot.from"
              :groups="fromTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.START')"
              @update:model-value="value => updateBreak(index, 'from', value)"
            />
            <Icon icon="i-lucide-minus size-4 text-n-slate-11" />
            <NextSelect
              :model-value="breakSlot.to"
              :groups="toTimeSlots"
              :placeholder="$t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.END')"
              @update:model-value="value => updateBreak(index, 'to', value)"
            />
            <button
              type="button"
              class="inline-flex items-center justify-center text-n-slate-11 hover:text-n-ruby-11"
              :aria-label="$t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.REMOVE')"
              :title="$t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.REMOVE')"
              @click="removeBreak(index)"
            >
              <Icon icon="i-lucide-trash-2 size-4" />
            </button>
          </div>

          <span
            v-if="breakSlots.some(breakSlot => !breakSlot.valid)"
            class="error text-label-small text-n-ruby-9"
          >
            {{ $t('INBOX_MGMT.BUSINESS_HOURS.BREAKS.VALIDATION_ERROR') }}
          </span>
        </div>
      </div>
      <span v-else class="text-body-main text-n-slate-11">
        {{ $t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.CLOSED') }}
      </span>
    </td>
  </tr>
</template>
