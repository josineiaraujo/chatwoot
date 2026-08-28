import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import BusinessCalendarCatalog from '../components/BusinessCalendarCatalog.vue';
import businessCalendarAPI from '../api';

const mocks = vi.hoisted(() => ({
  alert: vi.fn(),
  store: {
    dispatch: vi.fn(),
    getters: {
      'teams/getTeams': [
        { id: 12, name: 'Suporte' },
        { id: 7, name: 'Comercial' },
      ],
    },
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('vuex', async importOriginal => ({
  ...(await importOriginal()),
  useStore: () => mocks.store,
}));

vi.mock('dashboard/composables', () => ({
  useAlert: message => mocks.alert(message),
}));

vi.mock('../api', () => ({
  default: {
    getCalendars: vi.fn(),
    getCalendar: vi.fn(),
    createCalendar: vi.fn(),
    updateCalendar: vi.fn(),
    updateCalendarTeamLinks: vi.fn(),
    deleteCalendar: vi.fn(),
    createHoliday: vi.fn(),
    updateHoliday: vi.fn(),
    deleteHoliday: vi.fn(),
    previewImport: vi.fn(),
    importHolidays: vi.fn(),
  },
}));

const mountComponent = () =>
  shallowMount(BusinessCalendarCatalog, {
    global: {
      stubs: {
        Button: true,
        Checkbox: true,
        Dialog: {
          emits: ['close'],
          template: '<div><slot /></div>',
          methods: {
            open: vi.fn(),
            close() {
              this.$emit('close');
            },
          },
        },
        IbsoftDialogHeader: {
          props: ['title', 'description', 'closeLabel'],
          emits: ['close'],
          template:
            '<button class="ibsoft-dialog-close" @click="$emit(\'close\')" />',
        },
        Spinner: true,
        ToggleSwitch: true,
        IbsoftSelect: {
          template: '<select><slot /></select>',
        },
      },
    },
  });

const mountWithFormSemantics = () =>
  shallowMount(BusinessCalendarCatalog, {
    global: {
      stubs: {
        Button: {
          inheritAttrs: false,
          props: ['label', 'type'],
          emits: ['click'],
          template: `
            <button
              :type="type"
              :data-label="label"
              @click="$emit('click')"
            >
              {{ label }}
            </button>
          `,
        },
        Checkbox: true,
        Dialog: {
          emits: ['confirm', 'close'],
          template: `
            <form @submit.prevent="$emit('confirm')">
              <slot />
            </form>
          `,
          methods: { open: vi.fn(), close: vi.fn() },
        },
        Spinner: true,
        ToggleSwitch: true,
        IbsoftSelect: {
          template: '<select><slot /></select>',
        },
      },
    },
  });

describe('BusinessCalendarCatalog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.store.dispatch.mockResolvedValue();
    businessCalendarAPI.getCalendars.mockResolvedValue({
      data: { calendars: [] },
    });
    businessCalendarAPI.getCalendar.mockResolvedValue({
      data: {
        id: 4,
        name: 'Feriados BA',
        team_ids: [7],
        holidays: [],
      },
    });
    businessCalendarAPI.updateCalendar.mockResolvedValue({ data: { id: 4 } });
    businessCalendarAPI.updateCalendarTeamLinks.mockResolvedValue({
      data: { id: 4 },
    });
    businessCalendarAPI.createCalendar.mockResolvedValue({ data: { id: 9 } });
    businessCalendarAPI.previewImport.mockResolvedValue({
      data: {
        holidays: [
          {
            holiday_date: '2026-01-01',
            name: 'Confraternizacao Universal',
          },
          {
            holiday_date: '2026-07-02',
            name: 'Independencia da Bahia',
          },
        ],
      },
    });
    businessCalendarAPI.importHolidays.mockResolvedValue({
      data: { imported: [{ holiday_date: '2026-01-01' }] },
    });
  });

  it('loads the departments from the shared Chatwoot store', async () => {
    mountComponent();
    await flushPromises();

    expect(mocks.store.dispatch).toHaveBeenCalledWith('teams/get');
  });

  it('formats holiday dates for display without timezone conversion', () => {
    const wrapper = mountComponent();

    expect(wrapper.vm.formatHolidayDate('2026-01-01')).toBe('01/01/2026');
  });

  it('closes both calendar modals from their header actions', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    const closeButtons = wrapper.findAll('.ibsoft-dialog-close');

    expect(closeButtons).toHaveLength(2);

    wrapper.vm.currentCalendar = { id: 4 };
    await closeButtons[0].trigger('click');
    expect(wrapper.vm.currentCalendar).toBeNull();

    wrapper.vm.importPreview = [{ holiday_date: '2026-01-01' }];
    await closeButtons[1].trigger('click');
    expect(wrapper.vm.importPreview).toEqual([]);
  });

  it('persists all selected departments when editing a calendar', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });
    wrapper.vm.toggleTeam(12, true);

    await wrapper.vm.saveCalendar();

    expect(businessCalendarAPI.updateCalendar).toHaveBeenCalledWith(4, {
      name: 'Feriados BA',
    });
    expect(businessCalendarAPI.updateCalendarTeamLinks).toHaveBeenCalledWith(
      4,
      [7, 12]
    );
  });

  it('links selected departments immediately after creating a calendar', async () => {
    const wrapper = mountComponent();
    wrapper.vm.calendarName = 'Feriados nacionais';
    wrapper.vm.toggleTeam(12, true);

    await wrapper.vm.saveCalendar();

    expect(businessCalendarAPI.createCalendar).toHaveBeenCalledWith({
      name: 'Feriados nacionais',
    });
    expect(businessCalendarAPI.updateCalendarTeamLinks).toHaveBeenCalledWith(
      9,
      [12]
    );
  });

  it('previews API holidays without submitting the calendar form', async () => {
    const wrapper = mountWithFormSemantics();
    await wrapper.vm.openEditor({ id: 4 });
    await wrapper.vm.openSyncDialog();
    await flushPromises();

    await wrapper
      .get('[data-label="IBSOFT_BUSINESS_CALENDAR.IMPORT.PREVIEW"]')
      .trigger('click');
    await flushPromises();

    expect(businessCalendarAPI.previewImport).toHaveBeenCalledWith(4, {
      year: new Date().getFullYear(),
      state_code: '',
      include_optional: false,
    });
    expect(businessCalendarAPI.updateCalendar).not.toHaveBeenCalled();
    expect(businessCalendarAPI.updateCalendarTeamLinks).not.toHaveBeenCalled();
    expect(wrapper.vm.importPreview).toHaveLength(2);
    expect(wrapper.vm.selectedImportDates).toEqual([]);
  });

  it('imports only selected holidays without submitting the calendar form', async () => {
    const wrapper = mountWithFormSemantics();
    await wrapper.vm.openEditor({ id: 4 });
    await wrapper.vm.openSyncDialog();
    await flushPromises();

    await wrapper
      .get('[data-label="IBSOFT_BUSINESS_CALENDAR.IMPORT.PREVIEW"]')
      .trigger('click');
    await flushPromises();
    wrapper.vm.toggleImportDate('2026-07-02', true);
    await wrapper.vm.$nextTick();
    await wrapper
      .get('[data-label="IBSOFT_BUSINESS_CALENDAR.IMPORT.CONFIRM"]')
      .trigger('click');
    await flushPromises();

    expect(businessCalendarAPI.importHolidays).toHaveBeenCalledWith(4, {
      year: new Date().getFullYear(),
      state_code: '',
      include_optional: false,
      holiday_dates: ['2026-07-02'],
    });
    expect(businessCalendarAPI.updateCalendar).not.toHaveBeenCalled();
    expect(businessCalendarAPI.updateCalendarTeamLinks).not.toHaveBeenCalled();
  });

  it('selects and clears all holidays returned by the API', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });
    await wrapper.vm.previewImport();

    wrapper.vm.toggleAllImportDates(true);
    expect(wrapper.vm.selectedImportDates).toEqual([
      '2026-01-01',
      '2026-07-02',
    ]);

    wrapper.vm.toggleAllImportDates(false);
    expect(wrapper.vm.selectedImportDates).toEqual([]);
  });

  it('filters departments by name without changing the shared store list', () => {
    const wrapper = mountComponent();

    wrapper.vm.teamSearch = 'SUP';

    expect(wrapper.vm.filteredTeams).toEqual([{ id: 12, name: 'Suporte' }]);
    expect(mocks.store.getters['teams/getTeams']).toHaveLength(2);
  });

  it('creates a holiday and refreshes the edited calendar', async () => {
    businessCalendarAPI.createHoliday.mockResolvedValue({ data: { id: 31 } });
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });
    wrapper.vm.holidayForm = {
      id: null,
      holiday_date: '2026-12-25',
      name: 'Natal',
      holiday_kind: 'holiday',
    };

    await wrapper.vm.saveHoliday();

    expect(businessCalendarAPI.createHoliday).toHaveBeenCalledWith(4, {
      holiday_date: '2026-12-25',
      name: 'Natal',
      holiday_kind: 'holiday',
    });
    expect(businessCalendarAPI.getCalendar).toHaveBeenCalledTimes(2);
    expect(wrapper.vm.holidayForm.name).toBe('');
  });

  it('updates an existing holiday without creating a duplicate', async () => {
    businessCalendarAPI.updateHoliday.mockResolvedValue({ data: { id: 31 } });
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });
    wrapper.vm.editHoliday({
      id: 31,
      holiday_date: '2026-12-24',
      name: 'Recesso',
      holiday_kind: 'optional',
    });

    await wrapper.vm.saveHoliday();

    expect(businessCalendarAPI.updateHoliday).toHaveBeenCalledWith(4, 31, {
      holiday_date: '2026-12-24',
      name: 'Recesso',
      holiday_kind: 'optional',
    });
    expect(businessCalendarAPI.createHoliday).not.toHaveBeenCalled();
  });

  it('deletes a holiday and refreshes both detail and catalog', async () => {
    businessCalendarAPI.deleteHoliday.mockResolvedValue({});
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });

    await wrapper.vm.deleteHoliday(31);

    expect(businessCalendarAPI.deleteHoliday).toHaveBeenCalledWith(4, 31);
    expect(businessCalendarAPI.getCalendar).toHaveBeenCalledTimes(2);
    expect(businessCalendarAPI.getCalendars).toHaveBeenCalledTimes(2);
  });

  it('does not import holidays until at least one date is selected', async () => {
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });
    await wrapper.vm.previewImport();

    await wrapper.vm.importHolidays();

    expect(businessCalendarAPI.importHolidays).not.toHaveBeenCalled();
    expect(wrapper.vm.isImporting).toBe(false);
  });

  it('reports import failures without keeping the interface loading', async () => {
    businessCalendarAPI.previewImport.mockRejectedValue(
      new Error('request failed')
    );
    const wrapper = mountComponent();
    await wrapper.vm.openEditor({ id: 4 });

    await wrapper.vm.previewImport();

    expect(mocks.alert).toHaveBeenCalledWith(
      'IBSOFT_BUSINESS_CALENDAR.ERRORS.IMPORT'
    );
    expect(wrapper.vm.isImporting).toBe(false);
    expect(wrapper.vm.hasPreviewedImport).toBe(false);
  });
});
