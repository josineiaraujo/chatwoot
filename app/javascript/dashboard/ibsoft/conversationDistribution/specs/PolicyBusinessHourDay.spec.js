import { shallowMount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import PolicyBusinessHourDay from '../components/PolicyBusinessHourDay.vue';

const mountComponent = props =>
  shallowMount(PolicyBusinessHourDay, {
    props: {
      dayName: 'Segunda-feira',
      timeSlot: {
        day: 1,
        from: '09:00 AM',
        to: '05:00 PM',
        valid: true,
        openAllDay: false,
      },
      ...props,
    },
    global: {
      mocks: {
        $t: key => key,
      },
      stubs: {
        Icon: true,
        NextSelect: true,
        ToggleSwitch: true,
      },
    },
  });

describe('PolicyBusinessHourDay', () => {
  it('adds break slots to the policy day configuration', async () => {
    const wrapper = mountComponent({ breakSlots: [] });

    await wrapper.find('button').trigger('click');

    expect(wrapper.emitted('updateBreaks')).toEqual([
      [[{ from: '12:00 PM', to: '01:00 PM', valid: true }]],
    ]);
  });

  it('removes break slots from the policy day configuration', async () => {
    const wrapper = mountComponent({
      breakSlots: [{ from: '12:00 PM', to: '01:00 PM', valid: true }],
    });

    await wrapper.findAll('button').at(1).trigger('click');

    expect(wrapper.emitted('updateBreaks')).toEqual([[[]]]);
  });

  it('marks invalid break slots before emitting them', () => {
    const wrapper = mountComponent({
      breakSlots: [{ from: '12:00 PM', to: '01:00 PM', valid: true }],
    });

    wrapper.vm.updateBreak(0, 'to', '11:00 AM');

    expect(wrapper.emitted('updateBreaks')).toEqual([
      [[{ from: '12:00 PM', to: '11:00 AM', valid: false }]],
    ]);
  });
});
