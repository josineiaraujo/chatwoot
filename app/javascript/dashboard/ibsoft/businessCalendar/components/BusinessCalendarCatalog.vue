<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import businessCalendarAPI from '../api';

const { t } = useI18n();
const store = useStore();

const BRAZIL_STATES = Object.freeze([
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
]);

const calendars = ref([]);
const currentCalendar = ref(null);
const calendarName = ref('');
const isFetching = ref(false);
const isSaving = ref(false);
const isDeleting = ref(false);
const isSavingHoliday = ref(false);
const isImporting = ref(false);
const calendarToDelete = ref(null);
const editorRef = ref(null);
const syncDialogRef = ref(null);
const deleteDialogRef = ref(null);
const holidayForm = ref({});
const importForm = ref({});
const importPreview = ref([]);
const selectedImportDates = ref([]);
const selectedTeamIds = ref([]);
const teamSearch = ref('');
const activeEditorTab = ref('general');
const hasPreviewedImport = ref(false);

const emptyHoliday = () => ({
  id: null,
  holiday_date: '',
  name: '',
  holiday_kind: 'holiday',
});
const emptyImport = () => ({
  year: new Date().getFullYear(),
  state_code: '',
  include_optional: false,
});

const isEditing = computed(() => Boolean(currentCalendar.value?.id));
const editorTabs = computed(() => [
  {
    id: 'general',
    label: t('IBSOFT_BUSINESS_CALENDAR.EDITOR.TABS.GENERAL'),
  },
  {
    id: 'holidays',
    label: t('IBSOFT_BUSINESS_CALENDAR.EDITOR.TABS.HOLIDAYS'),
  },
  {
    id: 'departments',
    label: t('IBSOFT_BUSINESS_CALENDAR.EDITOR.TABS.DEPARTMENTS'),
  },
]);
const editorTitle = computed(() =>
  isEditing.value
    ? t('IBSOFT_BUSINESS_CALENDAR.EDITOR.EDIT_TITLE')
    : t('IBSOFT_BUSINESS_CALENDAR.EDITOR.CREATE_TITLE')
);
const invalidHoliday = computed(
  () => !holidayForm.value.holiday_date || !holidayForm.value.name?.trim()
);
const teams = computed(() =>
  [...(store.getters['teams/getTeams'] || [])].sort((first, second) =>
    first.name.localeCompare(second.name)
  )
);
const filteredTeams = computed(() => {
  const query = teamSearch.value.trim().toLocaleLowerCase();
  if (!query) return teams.value;

  return teams.value.filter(team =>
    team.name.toLocaleLowerCase().includes(query)
  );
});
const allImportDatesSelected = computed(
  () =>
    importPreview.value.length > 0 &&
    selectedImportDates.value.length === importPreview.value.length
);

const holidayKindLabel = holidayKind =>
  holidayKind === 'optional'
    ? t('IBSOFT_BUSINESS_CALENDAR.KINDS.OPTIONAL')
    : t('IBSOFT_BUSINESS_CALENDAR.KINDS.HOLIDAY');

const formatHolidayDate = value => {
  const match = String(value || '').match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return value || '';

  const [, year, month, day] = match;
  return `${day}/${month}/${year}`;
};

const fetchCalendars = async () => {
  isFetching.value = true;
  try {
    const { data } = await businessCalendarAPI.getCalendars();
    calendars.value = data.calendars || [];
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const loadCalendar = async calendarId => {
  const { data } = await businessCalendarAPI.getCalendar(calendarId);
  currentCalendar.value = data;
  calendarName.value = data.name;
  selectedTeamIds.value = [...(data.team_ids || [])];
};

const openEditor = async calendar => {
  currentCalendar.value = null;
  calendarName.value = calendar?.name || '';
  holidayForm.value = emptyHoliday();
  importForm.value = emptyImport();
  importPreview.value = [];
  selectedImportDates.value = [];
  selectedTeamIds.value = [];
  teamSearch.value = '';
  activeEditorTab.value = 'general';
  hasPreviewedImport.value = false;
  if (calendar?.id) await loadCalendar(calendar.id);
  await nextTick();
  editorRef.value?.open();
};

const closeEditor = () => {
  editorRef.value?.close();
};

const resetEditor = () => {
  currentCalendar.value = null;
  calendarName.value = '';
  holidayForm.value = emptyHoliday();
  importForm.value = emptyImport();
  importPreview.value = [];
  selectedImportDates.value = [];
  selectedTeamIds.value = [];
  teamSearch.value = '';
  activeEditorTab.value = 'general';
  hasPreviewedImport.value = false;
};

const openSyncDialog = async () => {
  importForm.value = emptyImport();
  importPreview.value = [];
  selectedImportDates.value = [];
  hasPreviewedImport.value = false;
  await nextTick();
  syncDialogRef.value?.open();
};

const resetSyncDialog = () => {
  importForm.value = emptyImport();
  importPreview.value = [];
  selectedImportDates.value = [];
  hasPreviewedImport.value = false;
};

const toggleImportDate = (holidayDate, selected) => {
  const dates = new Set(selectedImportDates.value);
  if (selected) dates.add(holidayDate);
  else dates.delete(holidayDate);
  selectedImportDates.value = [...dates];
};

const toggleAllImportDates = selected => {
  selectedImportDates.value = selected
    ? importPreview.value.map(holiday => holiday.holiday_date)
    : [];
};

const toggleTeam = (teamId, selected) => {
  const normalizedTeamId = Number(teamId);
  const nextTeamIds = new Set(selectedTeamIds.value.map(Number));
  if (selected) nextTeamIds.add(normalizedTeamId);
  else nextTeamIds.delete(normalizedTeamId);
  selectedTeamIds.value = [...nextTeamIds].sort(
    (first, second) => first - second
  );
};

const saveCalendar = async () => {
  isSaving.value = true;
  try {
    let calendarId;
    if (isEditing.value) {
      await businessCalendarAPI.updateCalendar(currentCalendar.value.id, {
        name: calendarName.value,
      });
      calendarId = currentCalendar.value.id;
    } else {
      const { data } = await businessCalendarAPI.createCalendar({
        name: calendarName.value,
      });
      calendarId = data.id;
    }
    await businessCalendarAPI.updateCalendarTeamLinks(
      calendarId,
      selectedTeamIds.value
    );
    await fetchCalendars();
    closeEditor();
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.SAVED'));
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const editHoliday = holiday => {
  holidayForm.value = { ...holiday };
};

const saveHoliday = async () => {
  if (!currentCalendar.value) return;

  isSavingHoliday.value = true;
  try {
    const payload = {
      holiday_date: holidayForm.value.holiday_date,
      name: holidayForm.value.name,
      holiday_kind: holidayForm.value.holiday_kind,
    };
    if (holidayForm.value.id) {
      await businessCalendarAPI.updateHoliday(
        currentCalendar.value.id,
        holidayForm.value.id,
        payload
      );
    } else {
      await businessCalendarAPI.createHoliday(
        currentCalendar.value.id,
        payload
      );
    }
    await loadCalendar(currentCalendar.value.id);
    await fetchCalendars();
    holidayForm.value = emptyHoliday();
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.SAVED'));
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.HOLIDAY_SAVE'));
  } finally {
    isSavingHoliday.value = false;
  }
};

const deleteHoliday = async holidayId => {
  try {
    await businessCalendarAPI.deleteHoliday(
      currentCalendar.value.id,
      holidayId
    );
    await loadCalendar(currentCalendar.value.id);
    await fetchCalendars();
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.DELETED'));
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.HOLIDAY_DELETE'));
  }
};

const previewImport = async () => {
  isImporting.value = true;
  selectedImportDates.value = [];
  hasPreviewedImport.value = false;
  try {
    const { data } = await businessCalendarAPI.previewImport(
      currentCalendar.value.id,
      importForm.value
    );
    importPreview.value = data.holidays || [];
    hasPreviewedImport.value = true;
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.IMPORT'));
  } finally {
    isImporting.value = false;
  }
};

const importHolidays = async () => {
  if (!selectedImportDates.value.length) return;

  isImporting.value = true;
  try {
    await businessCalendarAPI.importHolidays(currentCalendar.value.id, {
      ...importForm.value,
      holiday_dates: selectedImportDates.value,
    });
    await loadCalendar(currentCalendar.value.id);
    await fetchCalendars();
    syncDialogRef.value?.close();
    resetSyncDialog();
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.IMPORT.IMPORTED'));
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.IMPORT'));
  } finally {
    isImporting.value = false;
  }
};

const openDeleteDialog = async calendar => {
  calendarToDelete.value = calendar;
  await nextTick();
  deleteDialogRef.value?.open();
};

const deleteCalendar = async () => {
  if (!calendarToDelete.value) return;

  isDeleting.value = true;
  try {
    await businessCalendarAPI.deleteCalendar(calendarToDelete.value.id);
    await fetchCalendars();
    deleteDialogRef.value?.close();
    calendarToDelete.value = null;
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.DELETED'));
  } catch {
    useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.DELETE'));
  } finally {
    isDeleting.value = false;
  }
};

onMounted(() => {
  fetchCalendars();
  store
    .dispatch('teams/get')
    .catch(() => useAlert(t('IBSOFT_BUSINESS_CALENDAR.ERRORS.TEAMS_LOAD')));
});
</script>

<template>
  <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
    <div
      class="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
    >
      <div>
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_BUSINESS_CALENDAR.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ t('IBSOFT_BUSINESS_CALENDAR.DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="t('IBSOFT_BUSINESS_CALENDAR.NEW')"
        icon="i-lucide-plus"
        @click="openEditor()"
      />
    </div>

    <div v-if="isFetching" class="grid min-h-48 place-content-center">
      <Spinner />
    </div>

    <div v-else-if="calendars.length" class="grid gap-3">
      <article
        v-for="calendar in calendars"
        :key="calendar.id"
        class="flex flex-col gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-4 md:flex-row md:items-center md:justify-between"
      >
        <div class="min-w-0">
          <h3 class="mb-1 truncate text-heading-3 text-n-slate-12">
            {{ calendar.name }}
          </h3>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t('IBSOFT_BUSINESS_CALENDAR.CARD.SUMMARY', {
                holidays: calendar.holiday_count || 0,
                teams: calendar.team_ids?.length || 0,
              })
            }}
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-1">
          <Button
            :label="t('IBSOFT_BUSINESS_CALENDAR.ACTIONS.EDIT')"
            icon="i-lucide-pencil"
            variant="ghost"
            color="slate"
            @click="openEditor(calendar)"
          />
          <Button
            :label="t('IBSOFT_BUSINESS_CALENDAR.ACTIONS.DELETE')"
            icon="i-lucide-trash-2"
            variant="ghost"
            color="ruby"
            @click="openDeleteDialog(calendar)"
          />
        </div>
      </article>
    </div>

    <div
      v-else
      class="grid min-h-48 place-content-center rounded-lg border border-dashed border-n-weak p-6 text-center text-body-main text-n-slate-11"
    >
      {{ t('IBSOFT_BUSINESS_CALENDAR.EMPTY') }}
    </div>

    <Dialog
      ref="editorRef"
      width="3xl"
      position="top"
      overflow-y-auto
      :title="editorTitle"
      :confirm-button-label="t('IBSOFT_BUSINESS_CALENDAR.ACTIONS.SAVE')"
      :disable-confirm-button="!calendarName.trim()"
      :is-loading="isSaving"
      @confirm="saveCalendar"
      @close="resetEditor"
    >
      <div
        class="mb-5 flex gap-1 rounded-lg bg-n-alpha-1 p-1"
        role="tablist"
        :aria-label="t('IBSOFT_BUSINESS_CALENDAR.EDITOR.TABS.LABEL')"
      >
        <Button
          v-for="tab in editorTabs"
          :key="tab.id"
          :label="tab.label"
          size="sm"
          type="button"
          :variant="activeEditorTab === tab.id ? 'solid' : 'ghost'"
          :color="activeEditorTab === tab.id ? 'blue' : 'slate'"
          class="flex-1 justify-center"
          role="tab"
          :aria-selected="activeEditorTab === tab.id"
          @click="activeEditorTab = tab.id"
        />
      </div>

      <div v-if="activeEditorTab === 'general'" role="tabpanel">
        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_BUSINESS_CALENDAR.FIELDS.NAME') }}
          </span>
          <input
            v-model="calendarName"
            type="text"
            class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>
      </div>

      <section
        v-else-if="activeEditorTab === 'holidays'"
        class="grid gap-4"
        role="tabpanel"
      >
        <div
          class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"
        >
          <div>
            <h3 class="mb-1 text-heading-3 text-n-slate-12">
              {{ t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.TITLE') }}
            </h3>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{ t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.DESCRIPTION') }}
            </p>
          </div>
          <Button
            :label="t('IBSOFT_BUSINESS_CALENDAR.IMPORT.OPEN')"
            icon="i-lucide-cloud-download"
            color="slate"
            variant="faded"
            type="button"
            :disabled="!isEditing"
            @click="openSyncDialog"
          />
        </div>

        <div
          v-if="!isEditing"
          class="rounded-lg border border-n-weak bg-n-alpha-1 p-3 text-body-small text-n-slate-11"
        >
          {{ t('IBSOFT_BUSINESS_CALENDAR.EDITOR.SAVE_BEFORE_HOLIDAYS') }}
        </div>

        <template v-else>
          <div
            class="grid gap-3 md:grid-cols-[11rem_minmax(0,1fr)_12rem_auto] md:items-end"
          >
            <label class="grid gap-1">
              <span class="text-label-small text-n-slate-11">
                {{ t('IBSOFT_BUSINESS_CALENDAR.FIELDS.DATE') }}
              </span>
              <input
                v-model="holidayForm.holiday_date"
                type="date"
                class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              />
            </label>
            <label class="grid gap-1">
              <span class="text-label-small text-n-slate-11">
                {{ t('IBSOFT_BUSINESS_CALENDAR.FIELDS.HOLIDAY_NAME') }}
              </span>
              <input
                v-model="holidayForm.name"
                type="text"
                class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
              />
            </label>
            <label class="grid gap-1">
              <span class="text-label-small text-n-slate-11">
                {{ t('IBSOFT_BUSINESS_CALENDAR.FIELDS.KIND') }}
              </span>
              <IbsoftSelect v-model="holidayForm.holiday_kind">
                <option value="holiday">
                  {{ t('IBSOFT_BUSINESS_CALENDAR.KINDS.HOLIDAY') }}
                </option>
                <option value="optional">
                  {{ t('IBSOFT_BUSINESS_CALENDAR.KINDS.OPTIONAL') }}
                </option>
              </IbsoftSelect>
            </label>
            <Button
              :label="t('IBSOFT_BUSINESS_CALENDAR.ACTIONS.ADD')"
              :icon="holidayForm.id ? 'i-lucide-save' : 'i-lucide-plus'"
              :disabled="invalidHoliday"
              :is-loading="isSavingHoliday"
              type="button"
              @click="saveHoliday"
            />
          </div>

          <div class="max-h-72 overflow-y-auto rounded-lg border border-n-weak">
            <div
              v-for="holiday in currentCalendar.holidays"
              :key="holiday.id"
              class="flex items-center justify-between gap-3 border-b border-n-weak px-3 py-2 last:border-b-0"
            >
              <div class="min-w-0">
                <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
                  {{ holiday.name }}
                </p>
                <p class="mb-0 text-body-mini text-n-slate-10">
                  {{
                    t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.DETAILS', {
                      date: formatHolidayDate(holiday.holiday_date),
                      kind: holidayKindLabel(holiday.holiday_kind),
                    })
                  }}
                </p>
              </div>
              <div class="flex shrink-0 gap-1">
                <Button
                  icon="i-lucide-pencil"
                  variant="ghost"
                  color="slate"
                  type="button"
                  @click="editHoliday(holiday)"
                />
                <Button
                  icon="i-lucide-trash-2"
                  variant="ghost"
                  color="ruby"
                  type="button"
                  @click="deleteHoliday(holiday.id)"
                />
              </div>
            </div>
            <p
              v-if="!currentCalendar.holidays?.length"
              class="mb-0 p-4 text-center text-body-small text-n-slate-11"
            >
              {{ t('IBSOFT_BUSINESS_CALENDAR.HOLIDAYS.EMPTY') }}
            </p>
          </div>
        </template>
      </section>

      <section v-else class="grid gap-3" role="tabpanel">
        <div
          class="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between"
        >
          <div>
            <h3 class="mb-1 text-heading-3 text-n-slate-12">
              {{ t('IBSOFT_BUSINESS_CALENDAR.DEPARTMENTS.TITLE') }}
            </h3>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{ t('IBSOFT_BUSINESS_CALENDAR.DEPARTMENTS.DESCRIPTION') }}
            </p>
          </div>
          <span class="text-body-small text-n-slate-11">
            {{
              t('IBSOFT_BUSINESS_CALENDAR.DEPARTMENTS.SELECTED', {
                count: selectedTeamIds.length,
              })
            }}
          </span>
        </div>

        <input
          v-model="teamSearch"
          type="search"
          :placeholder="t('IBSOFT_BUSINESS_CALENDAR.DEPARTMENTS.SEARCH')"
          class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
        />

        <div class="max-h-72 overflow-y-auto rounded-lg border border-n-weak">
          <label
            v-for="team in filteredTeams"
            :key="team.id"
            class="flex cursor-pointer items-center gap-3 border-b border-n-weak px-3 py-2.5 last:border-b-0 hover:bg-n-alpha-2"
          >
            <Checkbox
              :model-value="selectedTeamIds.includes(Number(team.id))"
              @update:model-value="selected => toggleTeam(team.id, selected)"
            />
            <span class="min-w-0 truncate text-sm text-n-slate-12">
              {{ team.name }}
            </span>
          </label>
          <p
            v-if="!filteredTeams.length"
            class="mb-0 p-4 text-center text-body-small text-n-slate-11"
          >
            {{ t('IBSOFT_BUSINESS_CALENDAR.DEPARTMENTS.EMPTY') }}
          </p>
        </div>
      </section>
    </Dialog>

    <Dialog
      ref="syncDialogRef"
      width="2xl"
      position="top"
      overflow-y-auto
      :title="t('IBSOFT_BUSINESS_CALENDAR.IMPORT.TITLE')"
      :description="t('IBSOFT_BUSINESS_CALENDAR.IMPORT.DESCRIPTION')"
      :show-cancel-button="false"
      :show-confirm-button="false"
      @close="resetSyncDialog"
    >
      <div class="grid gap-5">
        <div
          class="grid gap-3 md:grid-cols-[10rem_11rem_minmax(0,1fr)_auto] md:items-end"
        >
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.YEAR') }}
            </span>
            <input
              v-model.number="importForm.year"
              type="number"
              min="2020"
              max="2100"
              class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
            />
          </label>
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.STATE') }}
            </span>
            <IbsoftSelect v-model="importForm.state_code">
              <option value="">
                {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.NATIONAL') }}
              </option>
              <option
                v-for="state in BRAZIL_STATES"
                :key="state"
                :value="state"
              >
                {{ state }}
              </option>
            </IbsoftSelect>
          </label>
          <label
            class="flex min-h-10 items-center justify-between gap-3 rounded-lg border border-n-weak px-3"
          >
            <span class="text-sm text-n-slate-12">
              {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.INCLUDE_OPTIONAL') }}
            </span>
            <ToggleSwitch v-model="importForm.include_optional" />
          </label>
          <Button
            :label="t('IBSOFT_BUSINESS_CALENDAR.IMPORT.PREVIEW')"
            icon="i-lucide-search"
            :is-loading="isImporting"
            type="button"
            @click="previewImport"
          />
        </div>

        <template v-if="hasPreviewedImport">
          <div v-if="importPreview.length" class="grid gap-3">
            <div
              class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
            >
              <label class="flex cursor-pointer items-center gap-3">
                <Checkbox
                  :model-value="allImportDatesSelected"
                  @update:model-value="toggleAllImportDates"
                />
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.SELECT_ALL') }}
                </span>
              </label>
              <span class="text-body-small text-n-slate-11">
                {{
                  t('IBSOFT_BUSINESS_CALENDAR.IMPORT.SELECTED', {
                    selected: selectedImportDates.length,
                    total: importPreview.length,
                  })
                }}
              </span>
            </div>

            <div
              class="max-h-80 overflow-y-auto rounded-lg border border-n-weak"
            >
              <label
                v-for="holiday in importPreview"
                :key="`${holiday.holiday_date}-${holiday.name}`"
                class="flex cursor-pointer items-center gap-3 border-b border-n-weak px-3 py-2.5 last:border-b-0 hover:bg-n-alpha-2"
              >
                <Checkbox
                  :model-value="
                    selectedImportDates.includes(holiday.holiday_date)
                  "
                  @update:model-value="
                    selected => toggleImportDate(holiday.holiday_date, selected)
                  "
                />
                <span class="min-w-0">
                  <span class="block truncate text-sm text-n-slate-12">
                    {{ holiday.name }}
                  </span>
                  <span class="block text-body-mini text-n-slate-10">
                    {{ formatHolidayDate(holiday.holiday_date) }}
                  </span>
                </span>
              </label>
            </div>

            <div class="flex justify-end">
              <Button
                :label="t('IBSOFT_BUSINESS_CALENDAR.IMPORT.CONFIRM')"
                icon="i-lucide-download"
                :disabled="!selectedImportDates.length"
                :is-loading="isImporting"
                type="button"
                @click="importHolidays"
              />
            </div>
          </div>

          <div
            v-else
            class="rounded-lg border border-dashed border-n-weak p-6 text-center text-body-small text-n-slate-11"
          >
            {{ t('IBSOFT_BUSINESS_CALENDAR.IMPORT.EMPTY') }}
          </div>
        </template>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('IBSOFT_BUSINESS_CALENDAR.DELETE.TITLE')"
      :description="t('IBSOFT_BUSINESS_CALENDAR.DELETE.DESCRIPTION')"
      :confirm-button-label="t('IBSOFT_BUSINESS_CALENDAR.ACTIONS.DELETE')"
      :is-loading="isDeleting"
      @confirm="deleteCalendar"
      @close="calendarToDelete = null"
    />
  </section>
</template>
