<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Avatar from 'next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import agentProvisioningAPI from '../api';

const { t } = useI18n();

const agents = ref([]);
const profiles = ref([]);
const createdAgent = ref(null);
const temporaryPassword = ref('');
const isFetching = ref(false);
const isCreating = ref(false);
const isUpdating = ref(false);
const isDeleting = ref(false);
const isGeneratingPassword = ref(false);
const updatingAvailabilityAgentId = ref(null);
const agentDialogRef = ref(null);
const editAgentDialogRef = ref(null);
const deleteAgentDialogRef = ref(null);
const cropDialogRef = ref(null);
const cropAreaRef = ref(null);
const cropImageRef = ref(null);
const editingAgent = ref(null);
const agentToDelete = ref(null);
const generatedEditPassword = ref('');
const cropTarget = ref('');
const cropImageUrl = ref('');
const cropSourceFile = ref(null);
const cropZoom = ref(1);
const cropPreviewSize = 256;
const cropImageSize = reactive({ width: 0, height: 0 });
const cropOffset = reactive({ x: 0, y: 0 });
const cropDrag = reactive({
  active: false,
  startX: 0,
  startY: 0,
  originX: 0,
  originY: 0,
});

const form = reactive({
  name: '',
  email: '',
  profileValue: 'agent',
  autoOffline: true,
  avatarFile: null,
  avatarUrl: '',
});

const editForm = reactive({
  name: '',
  email: '',
  profileValue: 'agent',
  availability: 'offline',
  autoOffline: true,
  avatarFile: null,
  avatarUrl: '',
  removeAvatar: false,
});

const availabilityOptions = computed(() => [
  {
    value: 'online',
    label: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY.ONLINE'
    ),
  },
  {
    value: 'busy',
    label: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY.BUSY'
    ),
  },
  {
    value: 'offline',
    label: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY.OFFLINE'
    ),
  },
]);

const profileOptions = computed(() => {
  const nativeProfiles = [
    {
      value: 'administrator',
      role: 'administrator',
      profileId: null,
      label: t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PROFILES.ADMINISTRATOR'
      ),
    },
    {
      value: 'agent',
      role: 'agent',
      profileId: null,
      label: t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PROFILES.AGENT'
      ),
    },
  ];

  const customProfiles = profiles.value.map(profile => ({
    value: `profile:${profile.id}`,
    role: 'agent',
    profileId: profile.id,
    label: profile.name,
  }));

  return [...nativeProfiles, ...customProfiles];
});

const selectedProfile = computed(() =>
  profileOptions.value.find(option => option.value === form.profileValue)
);

const selectedEditProfile = computed(() =>
  profileOptions.value.find(option => option.value === editForm.profileValue)
);

const isFormInvalid = computed(
  () => !form.name.trim() || !form.email.trim() || !selectedProfile.value
);

const isEditFormInvalid = computed(
  () =>
    !editingAgent.value ||
    !editForm.name.trim() ||
    !editForm.email.trim() ||
    !selectedEditProfile.value
);

const sortedAgents = computed(() =>
  [...agents.value].sort((agentA, agentB) =>
    agentA.name.localeCompare(agentB.name)
  )
);

const resetForm = () => {
  form.name = '';
  form.email = '';
  form.profileValue = 'agent';
  form.autoOffline = true;
  form.avatarFile = null;
  form.avatarUrl = '';
};

const resetCreateState = () => {
  resetForm();
  temporaryPassword.value = '';
  createdAgent.value = null;
};

const resetEditState = () => {
  editForm.name = '';
  editForm.email = '';
  editForm.profileValue = 'agent';
  editForm.availability = 'offline';
  editForm.autoOffline = true;
  editForm.avatarFile = null;
  editForm.avatarUrl = '';
  editForm.removeAvatar = false;
  editingAgent.value = null;
  generatedEditPassword.value = '';
};

const fetchAgents = async () => {
  isFetching.value = true;
  try {
    const { data } = await agentProvisioningAPI.getAgents();
    agents.value = data.agents || [];
    profiles.value = data.profiles || [];
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const createAgent = async () => {
  if (isFormInvalid.value) return;

  isCreating.value = true;
  temporaryPassword.value = '';
  createdAgent.value = null;

  try {
    const payload = {
      name: form.name.trim(),
      email: form.email.trim(),
      role: selectedProfile.value.role,
      profile_id: selectedProfile.value.profileId,
      auto_offline: form.autoOffline,
    };

    if (form.avatarFile) {
      payload.avatar = form.avatarFile;
    }

    const { data } = await agentProvisioningAPI.createAgent(payload);

    createdAgent.value = data.agent;
    temporaryPassword.value = data.temporary_password;
    resetForm();
    await fetchAgents();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CREATED'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_CREATE')
    );
  } finally {
    isCreating.value = false;
  }
};

const copyPassword = async password => {
  if (!password) return;

  try {
    await navigator.clipboard.writeText(password);
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PASSWORD_COPIED')
    );
  } catch {
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PASSWORD_COPY_ERROR')
    );
  }
};

const profileValueForAgent = agent => {
  if (agent.profile?.id) return `profile:${agent.profile.id}`;

  return agent.role === 'administrator' ? 'administrator' : 'agent';
};

const profileLabel = agent => {
  if (agent.profile?.name) return agent.profile.name;

  return (
    profileOptions.value.find(
      option => option.role === agent.role && !option.profileId
    )?.label || agent.role
  );
};

const availabilityValueForAgent = agent =>
  agent.availability_status || agent.availability || 'offline';

const replaceAgent = nextAgent => {
  agents.value = agents.value.map(agent =>
    agent.id === nextAgent.id ? { ...agent, ...nextAgent } : agent
  );
};

const openAgentDialog = () => {
  resetCreateState();
  agentDialogRef.value?.open();
};

const openEditAgent = agent => {
  editingAgent.value = agent;
  editForm.name = agent.name || '';
  editForm.email = agent.email || '';
  editForm.profileValue = profileValueForAgent(agent);
  editForm.availability = availabilityValueForAgent(agent);
  editForm.autoOffline = agent.auto_offline ?? true;
  editForm.avatarFile = null;
  editForm.avatarUrl = agent.thumbnail || '';
  editForm.removeAvatar = false;
  generatedEditPassword.value = '';
  editAgentDialogRef.value?.open();
};

const updateAgent = async () => {
  if (isEditFormInvalid.value) return;

  isUpdating.value = true;

  try {
    const agent = editingAgent.value;
    const profile = selectedEditProfile.value;
    const payload = {
      name: editForm.name.trim(),
      email: editForm.email.trim(),
      role: profile.role,
      availability: editForm.availability,
      auto_offline: editForm.autoOffline,
    };

    if (editForm.avatarFile) {
      payload.avatar = editForm.avatarFile;
    } else if (editForm.removeAvatar) {
      payload.remove_avatar = true;
    }

    await agentProvisioningAPI.updateAgent(agent.id, payload);

    if (profile.profileId) {
      await agentProvisioningAPI.saveProfileAssignment({
        userId: agent.id,
        roleId: profile.profileId,
      });
    } else if (agent.profile_assignment_id) {
      await agentProvisioningAPI.deleteProfileAssignment(
        agent.profile_assignment_id
      );
    }

    await fetchAgents();
    editAgentDialogRef.value?.close();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.UPDATED'));
  } catch {
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_UPDATE')
    );
  } finally {
    isUpdating.value = false;
  }
};

const updateAgentAvailability = async (agent, availability) => {
  const previousAvailability = availabilityValueForAgent(agent);

  if (!availability || availability === previousAvailability) return;

  updatingAvailabilityAgentId.value = agent.id;
  replaceAgent({
    ...agent,
    availability,
    availability_status: availability,
  });

  try {
    const { data } = await agentProvisioningAPI.updateAgent(agent.id, {
      availability,
    });
    replaceAgent(data.agent);
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY_UPDATED')
    );
  } catch {
    replaceAgent({
      ...agent,
      availability: previousAvailability,
      availability_status: previousAvailability,
    });
    useAlert(
      t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_AVAILABILITY_UPDATE'
      )
    );
  } finally {
    updatingAvailabilityAgentId.value = null;
  }
};

const generateEditTemporaryPassword = async () => {
  if (!editingAgent.value) return;

  isGeneratingPassword.value = true;
  generatedEditPassword.value = '';

  try {
    const { data } = await agentProvisioningAPI.resetTemporaryPassword(
      editingAgent.value.id
    );

    generatedEditPassword.value = data.temporary_password;
    editingAgent.value = data.agent || editingAgent.value;
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PASSWORD_REGENERATED')
    );
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t(
          'IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_PASSWORD_RESET'
        )
    );
  } finally {
    isGeneratingPassword.value = false;
  }
};

const openDeleteAgent = agent => {
  agentToDelete.value = agent;
  deleteAgentDialogRef.value?.open();
};

const clearCrop = () => {
  cropTarget.value = '';
  cropImageUrl.value = '';
  cropSourceFile.value = null;
  cropZoom.value = 1;
  cropImageSize.width = 0;
  cropImageSize.height = 0;
  cropOffset.x = 0;
  cropOffset.y = 0;
  cropDrag.active = false;
};

const openAvatarCrop = (target, { file, url }) => {
  if (!file || !url) return;

  cropTarget.value = target;
  cropSourceFile.value = file;
  cropImageUrl.value = url;
  cropZoom.value = 1;
  cropImageSize.width = 0;
  cropImageSize.height = 0;
  cropOffset.x = 0;
  cropOffset.y = 0;
  cropDialogRef.value?.open();
};

const cropBaseImageSize = computed(() => {
  const { width, height } = cropImageSize;

  if (!width || !height) {
    return { width: cropPreviewSize, height: cropPreviewSize };
  }

  const aspectRatio = width / height;

  if (aspectRatio >= 1) {
    return {
      width: cropPreviewSize * aspectRatio,
      height: cropPreviewSize,
    };
  }

  return {
    width: cropPreviewSize,
    height: cropPreviewSize / aspectRatio,
  };
});

const cropPreviewImageStyle = computed(() => ({
  width: `${cropBaseImageSize.value.width * cropZoom.value}px`,
  height: `${cropBaseImageSize.value.height * cropZoom.value}px`,
  transform: `translate(${cropOffset.x}px, ${cropOffset.y}px)`,
}));

const clampCropValue = (value, limit) =>
  Math.min(Math.max(value, -limit), limit);

const cropDragLimit = axis => {
  const zoom = Number(cropZoom.value) || 1;
  const size =
    axis === 'x'
      ? cropBaseImageSize.value.width
      : cropBaseImageSize.value.height;

  return Math.max((size * zoom - cropPreviewSize) / 2, 0);
};

const cropRenderedImageSize = image => {
  const aspectRatio = image.naturalWidth / image.naturalHeight;
  const zoom = Number(cropZoom.value) || 1;

  if (aspectRatio >= 1) {
    return {
      width: cropPreviewSize * aspectRatio * zoom,
      height: cropPreviewSize * zoom,
    };
  }

  return {
    width: cropPreviewSize * zoom,
    height: (cropPreviewSize / aspectRatio) * zoom,
  };
};

const cropDrawBounds = (image, outputSize) => {
  const areaRect = cropAreaRef.value?.getBoundingClientRect();
  const imageRect = cropImageRef.value?.getBoundingClientRect();

  if (areaRect?.width && imageRect?.width) {
    const outputScale = outputSize / areaRect.width;

    return {
      x: (imageRect.left - areaRect.left) * outputScale,
      y: (imageRect.top - areaRect.top) * outputScale,
      width: imageRect.width * outputScale,
      height: imageRect.height * outputScale,
    };
  }

  const renderedSize = cropRenderedImageSize(image);
  const outputScale = outputSize / cropPreviewSize;

  return {
    x:
      ((cropPreviewSize - renderedSize.width) / 2 + cropOffset.x) * outputScale,
    y:
      ((cropPreviewSize - renderedSize.height) / 2 + cropOffset.y) *
      outputScale,
    width: renderedSize.width * outputScale,
    height: renderedSize.height * outputScale,
  };
};

const clampCropOffset = () => {
  cropOffset.x = clampCropValue(cropOffset.x, cropDragLimit('x'));
  cropOffset.y = clampCropValue(cropOffset.y, cropDragLimit('y'));
};

const setCropImageSize = event => {
  cropImageSize.width = event.target.naturalWidth || 0;
  cropImageSize.height = event.target.naturalHeight || 0;
  clampCropOffset();
};

const startCropDrag = event => {
  cropDrag.active = true;
  cropDrag.startX = event.clientX;
  cropDrag.startY = event.clientY;
  cropDrag.originX = cropOffset.x;
  cropDrag.originY = cropOffset.y;
  event.currentTarget.setPointerCapture?.(event.pointerId);
};

const moveCropDrag = event => {
  if (!cropDrag.active) return;

  cropOffset.x = cropDrag.originX + event.clientX - cropDrag.startX;
  cropOffset.y = cropDrag.originY + event.clientY - cropDrag.startY;
  clampCropOffset();
};

const endCropDrag = event => {
  cropDrag.active = false;
  event.currentTarget.releasePointerCapture?.(event.pointerId);
};

const loadImage = url =>
  new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = url;
  });

const croppedAvatarFile = async () => {
  const image = await loadImage(cropImageUrl.value);
  const canvas = document.createElement('canvas');
  const outputSize = 512;
  const drawBounds = cropDrawBounds(image, outputSize);

  canvas.width = outputSize;
  canvas.height = outputSize;
  const context = canvas.getContext('2d');
  context.beginPath();
  context.arc(outputSize / 2, outputSize / 2, outputSize / 2, 0, Math.PI * 2);
  context.clip();
  context.drawImage(
    image,
    drawBounds.x,
    drawBounds.y,
    drawBounds.width,
    drawBounds.height
  );

  const blob = await new Promise(resolve => {
    canvas.toBlob(resolve, 'image/png');
  });

  return new File([blob], cropSourceFile.value.name || 'agent-avatar.png', {
    type: 'image/png',
  });
};

const applyAvatarCrop = async () => {
  if (!cropImageUrl.value) return;

  const file = await croppedAvatarFile();
  const url = URL.createObjectURL(file);

  if (cropTarget.value === 'edit') {
    editForm.avatarFile = file;
    editForm.avatarUrl = url;
    editForm.removeAvatar = false;
  } else {
    form.avatarFile = file;
    form.avatarUrl = url;
  }

  cropDialogRef.value?.close();
};

const removeCreateAvatar = () => {
  form.avatarFile = null;
  form.avatarUrl = '';
};

const removeEditAvatar = () => {
  editForm.avatarFile = null;
  editForm.avatarUrl = '';
  editForm.removeAvatar = Boolean(editingAgent.value?.thumbnail);
};

const closeDeleteAgent = () => {
  agentToDelete.value = null;
};

const deleteAgent = async () => {
  if (!agentToDelete.value) return;

  isDeleting.value = true;

  try {
    if (agentToDelete.value.profile_assignment_id) {
      await agentProvisioningAPI.deleteProfileAssignment(
        agentToDelete.value.profile_assignment_id
      );
    }

    await agentProvisioningAPI.deleteAgent(agentToDelete.value.id);
    await fetchAgents();
    deleteAgentDialogRef.value?.close();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DELETED'));
  } catch {
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.AGENT_PROVISIONING_DELETE')
    );
  } finally {
    isDeleting.value = false;
  }
};

onMounted(fetchAgents);
</script>

<template>
  <div class="grid gap-5">
    <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
      <div class="mb-4 flex items-start justify-between gap-3">
        <div>
          <h2 class="mb-1 text-heading-2 text-n-slate-12">
            {{
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.LIST_TITLE')
            }}
          </h2>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.LIST_DESCRIPTION'
              )
            }}
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <Button
            slate
            size="sm"
            icon="i-lucide-refresh-cw"
            :label="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.REFRESH')
            "
            :disabled="isFetching"
            @click="fetchAgents"
          />
          <Button
            size="sm"
            icon="i-lucide-user-plus"
            :label="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CREATE')
            "
            @click="openAgentDialog"
          />
        </div>
      </div>

      <div v-if="isFetching" class="grid min-h-40 place-content-center">
        <Spinner />
      </div>

      <div
        v-else
        class="divide-y divide-n-weak rounded-lg border border-n-weak"
      >
        <div v-if="!sortedAgents.length" class="p-4 text-sm text-n-slate-11">
          {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMPTY') }}
        </div>

        <div
          v-for="agent in sortedAgents"
          :key="agent.id"
          class="grid grid-cols-1 gap-x-4 gap-y-3 p-4 md:grid-cols-[minmax(0,1fr)_auto] md:items-center xl:grid-cols-[minmax(16rem,1fr)_9rem_minmax(12rem,auto)_auto]"
        >
          <div class="flex min-w-0 items-center gap-3">
            <Avatar
              :src="agent.thumbnail"
              :name="agent.name"
              :status="agent.availability_status"
              :size="36"
              rounded-full
              data-testid="agent-avatar"
            />
            <div class="min-w-0">
              <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
                {{ agent.name }}
              </p>
              <p class="mb-0 truncate text-xs text-n-slate-11">
                {{ agent.email }}
              </p>
            </div>
          </div>

          <IbsoftSelect
            :model-value="availabilityValueForAgent(agent)"
            :clearable="false"
            class="!w-36 justify-self-start md:justify-self-end xl:!w-full xl:justify-self-stretch"
            data-testid="agent-availability-select"
            :disabled="updatingAvailabilityAgentId === agent.id"
            @update:model-value="value => updateAgentAvailability(agent, value)"
          >
            <option
              v-for="option in availabilityOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>

          <div
            class="flex min-w-0 flex-wrap items-center gap-2 text-xs text-n-slate-11"
          >
            <span
              class="max-w-full truncate rounded-full bg-n-alpha-2 px-2 py-1"
            >
              {{ profileLabel(agent) }}
            </span>
            <span class="rounded-full bg-n-alpha-2 px-2 py-1">
              {{
                agent.confirmed
                  ? t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CONFIRMED'
                    )
                  : t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PENDING'
                    )
              }}
            </span>
          </div>

          <div class="flex items-center gap-1 md:justify-end">
            <Button
              ghost
              slate
              size="xs"
              icon="i-lucide-pencil"
              :label="
                t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EDIT')
              "
              data-testid="agent-edit-button"
              @click="openEditAgent(agent)"
            />
            <Button
              ghost
              ruby
              size="xs"
              icon="i-lucide-trash-2"
              :label="
                t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DELETE')
              "
              data-testid="agent-delete-button"
              @click="openDeleteAgent(agent)"
            />
          </div>
        </div>
      </div>
    </section>

    <Dialog
      ref="agentDialogRef"
      width="xl"
      position="top"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.TITLE')"
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DESCRIPTION')
      "
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CREATE')
      "
      :disable-confirm-button="isFormInvalid"
      :is-loading="isCreating"
      @confirm="createAgent"
      @close="resetCreateState"
    >
      <div class="grid gap-4">
        <label class="grid gap-2">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PICTURE') }}
          </span>
          <Avatar
            :src="form.avatarUrl"
            :name="
              form.name ||
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVATAR_FALLBACK'
              )
            "
            :size="72"
            allow-upload
            rounded-full
            @upload="payload => openAvatarCrop('create', payload)"
            @delete="removeCreateAvatar"
          />
        </label>

        <div class="grid gap-4 md:grid-cols-2">
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.NAME') }}
            </span>
            <input
              v-model="form.name"
              type="text"
              data-testid="agent-create-name"
              class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
              :placeholder="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.NAME_PLACEHOLDER'
                )
              "
            />
          </label>

          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMAIL') }}
            </span>
            <input
              v-model="form.email"
              type="email"
              data-testid="agent-create-email"
              class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
              :placeholder="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMAIL_PLACEHOLDER'
                )
              "
            />
          </label>
        </div>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PROFILE') }}
          </span>
          <IbsoftSelect
            v-model="form.profileValue"
            :clearable="false"
            data-testid="agent-create-profile"
          >
            <option
              v-for="option in profileOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>

        <section
          class="flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-alpha-1 px-4 py-3"
        >
          <div class="min-w-0">
            <h3 class="mb-0.5 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AUTO_OFFLINE.LABEL'
                )
              }}
            </h3>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AUTO_OFFLINE.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <ToggleSwitch
            v-model="form.autoOffline"
            data-testid="agent-create-auto-offline"
          />
        </section>

        <section
          v-if="temporaryPassword"
          class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div class="mb-3">
            <h3 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PASSWORD_TITLE'
                )
              }}
            </h3>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PASSWORD_DESCRIPTION',
                  { name: createdAgent?.name }
                )
              }}
            </p>
          </div>

          <div class="flex flex-col gap-3 md:flex-row">
            <input
              :value="temporaryPassword"
              type="text"
              readonly
              data-testid="agent-create-temporary-password"
              class="min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 font-mono text-sm text-n-slate-12"
            />
            <Button
              type="button"
              icon="i-lucide-copy"
              :label="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.COPY_PASSWORD'
                )
              "
              @click="copyPassword(temporaryPassword)"
            />
          </div>
        </section>
      </div>
    </Dialog>

    <Dialog
      ref="editAgentDialogRef"
      width="xl"
      position="top"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EDIT_TITLE')"
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EDIT_DESCRIPTION')
      "
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.UPDATE')
      "
      :disable-confirm-button="isEditFormInvalid"
      :is-loading="isUpdating"
      @confirm="updateAgent"
      @close="resetEditState"
    >
      <div class="grid gap-4">
        <label class="grid gap-2">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PICTURE') }}
          </span>
          <Avatar
            :src="editForm.avatarUrl"
            :name="
              editForm.name ||
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVATAR_FALLBACK'
              )
            "
            :size="72"
            allow-upload
            rounded-full
            @upload="payload => openAvatarCrop('edit', payload)"
            @delete="removeEditAvatar"
          />
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.NAME') }}
          </span>
          <input
            v-model="editForm.name"
            type="text"
            data-testid="agent-edit-name"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            :placeholder="
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.NAME_PLACEHOLDER'
              )
            "
          />
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMAIL') }}
          </span>
          <input
            v-model="editForm.email"
            type="email"
            data-testid="agent-edit-email"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            :placeholder="
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.EMAIL_PLACEHOLDER'
              )
            "
          />
        </label>

        <div class="grid gap-4 md:grid-cols-2">
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.PROFILE')
              }}
            </span>
            <IbsoftSelect
              v-model="editForm.profileValue"
              :clearable="false"
              data-testid="agent-edit-profile"
            >
              <option
                v-for="option in profileOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </IbsoftSelect>
          </label>

          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AVAILABILITY.LABEL'
                )
              }}
            </span>
            <IbsoftSelect
              v-model="editForm.availability"
              :clearable="false"
              data-testid="agent-edit-availability"
            >
              <option
                v-for="option in availabilityOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </IbsoftSelect>
          </label>
        </div>

        <section
          class="flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-alpha-1 px-4 py-3"
        >
          <div class="min-w-0">
            <h3 class="mb-0.5 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AUTO_OFFLINE.LABEL'
                )
              }}
            </h3>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.AUTO_OFFLINE.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <ToggleSwitch
            v-model="editForm.autoOffline"
            data-testid="agent-edit-auto-offline"
          />
        </section>

        <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
          <div class="mb-3 flex flex-col justify-between gap-3 md:flex-row">
            <div>
              <h3 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.RESET_PASSWORD_TITLE'
                  )
                }}
              </h3>
              <p class="mb-0 text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.RESET_PASSWORD_DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <Button
              type="button"
              slate
              icon="i-lucide-key-round"
              :label="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.GENERATE_PASSWORD'
                )
              "
              :is-loading="isGeneratingPassword"
              :disabled="isGeneratingPassword"
              data-testid="agent-reset-password-button"
              @click="generateEditTemporaryPassword"
            />
          </div>

          <div
            v-if="generatedEditPassword"
            class="flex flex-col gap-3 md:flex-row"
          >
            <input
              :value="generatedEditPassword"
              type="text"
              readonly
              data-testid="agent-edit-temporary-password"
              class="min-w-0 flex-1 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 font-mono text-sm text-n-slate-12"
            />
            <Button
              type="button"
              icon="i-lucide-copy"
              :label="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.COPY_PASSWORD'
                )
              "
              @click="copyPassword(generatedEditPassword)"
            />
          </div>
        </section>
      </div>
    </Dialog>

    <Dialog
      ref="cropDialogRef"
      width="lg"
      position="top"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CROP_TITLE')"
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CROP_DESCRIPTION')
      "
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.APPLY_CROP')
      "
      :cancel-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CANCEL_CROP')
      "
      @confirm="applyAvatarCrop"
      @close="clearCrop"
    >
      <div class="grid gap-4">
        <div
          ref="cropAreaRef"
          data-testid="agent-avatar-crop-area"
          class="mx-auto grid size-64 cursor-move touch-none place-items-center overflow-hidden rounded-full bg-n-alpha-2"
          @pointerdown="startCropDrag"
          @pointermove="moveCropDrag"
          @pointerup="endCropDrag"
          @pointercancel="endCropDrag"
        >
          <img
            v-if="cropImageUrl"
            ref="cropImageRef"
            :src="cropImageUrl"
            alt=""
            data-testid="agent-avatar-crop-image"
            class="block max-w-none select-none"
            draggable="false"
            :style="cropPreviewImageStyle"
            @load="setCropImageSize"
          />
        </div>

        <label class="grid gap-2">
          <span class="text-label-small text-n-slate-11">
            {{
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.CROP_ZOOM')
            }}
          </span>
          <input
            v-model="cropZoom"
            type="range"
            min="1"
            max="3"
            step="0.05"
            @input="clampCropOffset"
          />
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteAgentDialogRef"
      type="alert"
      width="md"
      :title="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DELETE_TITLE')
      "
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DELETE_MESSAGE', {
          name: agentToDelete?.name,
        })
      "
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.AGENT_PROVISIONING.DELETE_CONFIRM')
      "
      :is-loading="isDeleting"
      @confirm="deleteAgent"
      @close="closeDeleteAgent"
    />
  </div>
</template>
