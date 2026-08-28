<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import accessControlAPI from '../api';

const { t } = useI18n();

const roles = ref([]);
const assignments = ref([]);
const users = ref([]);
const availablePermissions = ref([]);
const selectedUserId = ref('');
const roleToDelete = ref(null);
const selectedRoleForUsers = ref(null);
const isFetching = ref(false);
const isSavingRole = ref(false);
const isDeletingRole = ref(false);
const isSavingAssignment = ref(false);
const isDeletingAssignment = ref(false);
const isCreatingRole = ref(false);
const editingRoleId = ref(null);
const roleDialogRef = ref(null);
const deleteRoleDialogRef = ref(null);
const roleUsersDialogRef = ref(null);

const roleForm = reactive({
  name: '',
  description: '',
  permissions: [],
});

const permissionGroups = computed(() =>
  availablePermissions.value.reduce((groups, permission) => {
    const group = permission.group || 'other';
    groups[group] ||= [];
    groups[group].push(permission);
    return groups;
  }, {})
);

const dialogTitle = computed(() =>
  isCreatingRole.value
    ? t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.CREATE_TITLE')
    : t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.EDIT_TITLE')
);

const isRoleFormInvalid = computed(
  () =>
    !roleForm.name.trim() ||
    !roleForm.description.trim() ||
    roleForm.permissions.length === 0
);

const selectedRoleAssignments = computed(() =>
  assignments.value.filter(
    assignment =>
      Number(assignment.role.id) === Number(selectedRoleForUsers.value?.id)
  )
);

const selectedRoleUserIds = computed(
  () =>
    new Set(
      selectedRoleAssignments.value.map(assignment =>
        Number(assignment.user.id)
      )
    )
);

const selectableUsersForRole = computed(() =>
  users.value.filter(user => !selectedRoleUserIds.value.has(Number(user.id)))
);

const permissionLabels = computed(() => ({
  conversation_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.CONVERSATION_MANAGE'
  ),
  conversation_unassigned_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.CONVERSATION_UNASSIGNED_MANAGE'
  ),
  conversation_participating_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.CONVERSATION_PARTICIPATING_MANAGE'
  ),
  contact_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.CONTACT_MANAGE'
  ),
  report_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.REPORT_MANAGE'
  ),
  knowledge_base_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.KNOWLEDGE_BASE_MANAGE'
  ),
  ibsoft_conversation_distribution_supervise: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.IBSOFT_CONVERSATION_DISTRIBUTION_SUPERVISE'
  ),
  ibsoft_chathub_settings_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.IBSOFT_CHATHUB_SETTINGS_MANAGE'
  ),
  ibsoft_message_broadcast_manage: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.PERMISSIONS.IBSOFT_MESSAGE_BROADCAST_MANAGE'
  ),
}));

const groupLabels = computed(() => ({
  conversation: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.GROUPS.CONVERSATION'
  ),
  workspace: t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.GROUPS.WORKSPACE'),
  ibsoft: t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.GROUPS.IBSOFT'),
}));

const permissionLabel = permission =>
  permissionLabels.value[permission] || permission;

const groupLabel = group => groupLabels.value[group] || group;

const assignmentForUser = user =>
  assignments.value.find(
    assignment => Number(assignment.user.id) === Number(user.id)
  );

const userOptionLabel = user => {
  const assignment = assignmentForUser(user);
  if (!assignment) {
    return t('IBSOFT_THEME.CHATHUB_SETTINGS.USER_OPTION', {
      name: user.name,
      email: user.email,
    });
  }

  return t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.USER_OPTION_WITH_PROFILE',
    {
      name: user.name,
      email: user.email,
      profile: assignment.role.name,
    }
  );
};

const rolePayload = () => ({
  name: roleForm.name.trim(),
  description: roleForm.description.trim(),
  permissions: roleForm.permissions,
});

const resetRoleForm = () => {
  editingRoleId.value = null;
  isCreatingRole.value = false;
  roleForm.name = '';
  roleForm.description = '';
  roleForm.permissions = [];
};

const fetchRoles = async () => {
  const { data } = await accessControlAPI.getRoles();
  roles.value = data.roles || [];
  availablePermissions.value = data.available_permissions || [];
};

const fetchAssignments = async () => {
  const { data } = await accessControlAPI.getAssignments();
  assignments.value = data.assignments || [];
  users.value = data.users || data.available_users || [];
};

const fetchAccessControl = async () => {
  isFetching.value = true;
  try {
    await Promise.all([fetchRoles(), fetchAssignments()]);
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.ACCESS_CONTROL_LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const openRoleDialog = async () => {
  await nextTick();
  roleDialogRef.value?.open();
};

const openCreateRole = () => {
  resetRoleForm();
  isCreatingRole.value = true;
  openRoleDialog();
};

const openEditRole = role => {
  editingRoleId.value = role.id;
  isCreatingRole.value = false;
  roleForm.name = role.name;
  roleForm.description = role.description || '';
  roleForm.permissions = [...(role.permissions || [])];
  openRoleDialog();
};

const togglePermission = permission => {
  const currentPermissions = new Set(roleForm.permissions);

  if (currentPermissions.has(permission)) {
    currentPermissions.delete(permission);
  } else {
    currentPermissions.add(permission);
    if (permission === 'conversation_manage') {
      currentPermissions.add('conversation_unassigned_manage');
      currentPermissions.add('conversation_participating_manage');
    }
  }

  roleForm.permissions = Array.from(currentPermissions);
};

const saveRole = async () => {
  isSavingRole.value = true;
  try {
    if (isCreatingRole.value) {
      await accessControlAPI.createRole(rolePayload());
    } else {
      await accessControlAPI.updateRole(editingRoleId.value, rolePayload());
    }

    await fetchAccessControl();
    roleDialogRef.value?.close();
    resetRoleForm();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.SAVED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.ACCESS_CONTROL_SAVE'));
  } finally {
    isSavingRole.value = false;
  }
};

const openDeleteRole = role => {
  roleToDelete.value = role;
  deleteRoleDialogRef.value?.open();
};

const closeDeleteRole = () => {
  roleToDelete.value = null;
  deleteRoleDialogRef.value?.close();
};

const openRoleUsers = async role => {
  selectedRoleForUsers.value = role;
  selectedUserId.value = '';
  await nextTick();
  roleUsersDialogRef.value?.open();
};

const closeRoleUsers = () => {
  selectedRoleForUsers.value = null;
  selectedUserId.value = '';
};

const confirmDeleteRole = async () => {
  if (!roleToDelete.value) return;

  isDeletingRole.value = true;
  try {
    await accessControlAPI.deleteRole(roleToDelete.value.id);
    await fetchAccessControl();
    closeDeleteRole();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.ACCESS_CONTROL_DELETE'));
  } finally {
    isDeletingRole.value = false;
  }
};

const addAssignment = async () => {
  if (!selectedUserId.value || !selectedRoleForUsers.value) return;

  isSavingAssignment.value = true;
  try {
    await accessControlAPI.saveAssignment({
      userId: selectedUserId.value,
      roleId: selectedRoleForUsers.value.id,
    });
    selectedUserId.value = '';
    await Promise.all([fetchRoles(), fetchAssignments()]);
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.ASSIGNMENT_SAVED')
    );
  } catch {
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.ACCESS_CONTROL_ASSIGNMENT')
    );
  } finally {
    isSavingAssignment.value = false;
  }
};

const deleteAssignment = async assignmentId => {
  isDeletingAssignment.value = true;
  try {
    await accessControlAPI.deleteAssignment(assignmentId);
    await Promise.all([fetchRoles(), fetchAssignments()]);
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.ASSIGNMENT_DELETED')
    );
  } catch {
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.ACCESS_CONTROL_ASSIGNMENT')
    );
  } finally {
    isDeletingAssignment.value = false;
  }
};

onMounted(fetchAccessControl);
</script>

<template>
  <section class="grid gap-5">
    <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
      <div
        class="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
      >
        <div>
          <h2 class="mb-1 text-heading-2 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.TITLE') }}
          </h2>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DESCRIPTION') }}
          </p>
        </div>
        <Button
          :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.NEW')"
          icon="i-lucide-plus"
          md
          @click="openCreateRole"
        />
      </div>

      <div v-if="isFetching" class="grid min-h-48 place-content-center">
        <Spinner />
      </div>

      <div v-else-if="roles.length" class="grid gap-3">
        <article
          v-for="role in roles"
          :key="role.id"
          class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="grid gap-3">
            <div
              class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
            >
              <div class="min-w-0">
                <h3 class="mb-1 text-base font-semibold text-n-slate-12">
                  {{ role.name }}
                </h3>
                <p class="mb-0 text-sm text-n-slate-11">
                  {{ role.description }}
                </p>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <span class="text-xs text-n-slate-11">
                  {{
                    t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.USAGE', {
                      count: role.assignments_count || 0,
                    })
                  }}
                </span>
                <Button
                  ghost
                  slate
                  sm
                  icon="i-lucide-users"
                  :label="
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.VIEW_AGENTS'
                    )
                  "
                  @click="openRoleUsers(role)"
                />
                <Button
                  ghost
                  slate
                  sm
                  icon="i-lucide-pencil"
                  :title="
                    t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.EDIT')
                  "
                  :aria-label="
                    t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.EDIT')
                  "
                  @click="openEditRole(role)"
                />
                <Button
                  ghost
                  ruby
                  sm
                  icon="i-lucide-trash-2"
                  :title="
                    t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETE')
                  "
                  :aria-label="
                    t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETE')
                  "
                  @click="openDeleteRole(role)"
                />
              </div>
            </div>
            <div class="flex w-full flex-wrap gap-2">
              <span
                v-for="permission in role.permissions"
                :key="permission"
                class="rounded-md bg-n-alpha-2 px-2 py-1 text-xs text-n-slate-12"
              >
                {{ permissionLabel(permission) }}
              </span>
            </div>
          </div>
        </article>
      </div>

      <div
        v-else
        class="grid min-h-48 place-content-center rounded-xl border border-dashed border-n-weak p-6 text-center text-body-main text-n-slate-11"
      >
        {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.EMPTY') }}
      </div>
    </section>

    <Dialog
      ref="roleDialogRef"
      width="2xl"
      position="top"
      overflow-y-auto
      :title="dialogTitle"
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.SAVE')
      "
      :disable-confirm-button="isRoleFormInvalid"
      :is-loading="isSavingRole"
      @confirm="saveRole"
      @close="resetRoleForm"
    >
      <div class="grid gap-4">
        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.NAME') }}
          </span>
          <input
            v-model.trim="roleForm.name"
            type="text"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
          />
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DESCRIPTION_FIELD'
              )
            }}
          </span>
          <textarea
            v-model.trim="roleForm.description"
            rows="3"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
          />
        </label>

        <div class="grid gap-4">
          <div
            v-for="(permissions, group) in permissionGroups"
            :key="group"
            class="rounded-xl border border-n-weak p-3"
          >
            <h4 class="mb-3 text-sm font-semibold text-n-slate-12">
              {{ groupLabel(group) }}
            </h4>
            <div class="grid gap-2">
              <button
                v-for="permission in permissions"
                :key="permission.key"
                type="button"
                class="flex items-center justify-between gap-3 rounded-lg px-3 py-2 text-left hover:bg-n-alpha-1"
                @click="togglePermission(permission.key)"
              >
                <span class="text-sm text-n-slate-12">
                  {{ permissionLabel(permission.key) }}
                </span>
                <span
                  class="grid size-5 place-content-center rounded border border-n-weak"
                  :class="
                    roleForm.permissions.includes(permission.key)
                      ? 'bg-n-brand text-white'
                      : 'bg-n-alpha-1 text-transparent'
                  "
                >
                  <i class="i-lucide-check size-3" />
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="roleUsersDialogRef"
      width="2xl"
      position="top"
      overflow-y-auto
      :title="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.MANAGE_AGENTS_TITLE', {
          profile: selectedRoleForUsers?.name,
        })
      "
      :description="
        t(
          'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.MANAGE_AGENTS_DESCRIPTION'
        )
      "
      :show-confirm-button="false"
      @close="closeRoleUsers"
    >
      <div class="grid gap-4">
        <div class="grid gap-2 md:grid-cols-[1fr_auto]">
          <IbsoftSelect
            v-model="selectedUserId"
            :disabled="isSavingAssignment || !selectableUsersForRole.length"
          >
            <option value="">
              {{
                t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.SELECT_USER')
              }}
            </option>
            <option
              v-for="user in selectableUsersForRole"
              :key="user.id"
              :value="user.id"
            >
              {{ userOptionLabel(user) }}
            </option>
          </IbsoftSelect>

          <Button
            :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.ADD_AGENT')"
            icon="i-lucide-user-plus"
            :disabled="!selectedUserId || isSavingAssignment"
            :is-loading="isSavingAssignment"
            @click="addAssignment"
          />
        </div>

        <div class="divide-y divide-n-weak rounded-xl border border-n-weak">
          <div
            v-if="!selectedRoleAssignments.length"
            class="p-4 text-sm text-n-slate-11"
          >
            {{
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.ASSIGNMENTS_EMPTY'
              )
            }}
          </div>
          <div
            v-for="assignment in selectedRoleAssignments"
            :key="assignment.id"
            class="flex flex-col justify-between gap-3 p-3 md:flex-row md:items-center"
          >
            <div class="min-w-0">
              <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
                {{ assignment.user.name }}
              </p>
              <p class="mb-0 truncate text-xs text-n-slate-11">
                {{ assignment.user.email }}
              </p>
            </div>

            <Button
              ghost
              ruby
              sm
              icon="i-lucide-user-minus"
              :label="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.REMOVE_ASSIGNMENT'
                )
              "
              :disabled="isDeletingAssignment"
              @click="deleteAssignment(assignment.id)"
            />
          </div>
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="deleteRoleDialogRef"
      type="alert"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETE_TITLE')"
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETE_MESSAGE')
      "
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ACCESS_CONTROL.DELETE_CONFIRM')
      "
      :is-loading="isDeletingRole"
      @confirm="confirmDeleteRole"
      @close="closeDeleteRole"
    />
  </section>
</template>
