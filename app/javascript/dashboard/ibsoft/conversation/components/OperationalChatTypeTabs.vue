<script setup>
import { computed, ref } from 'vue';
import { vOnClickOutside } from '@vueuse/components';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import ChatTypeTabs from 'dashboard/components/widgets/ChatTypeTabs.vue';

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  overflowItems: {
    type: Array,
    default: () => [],
  },
  activeTab: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['chatTabChange']);

const { t } = useI18n();
const showOverflowMenu = ref(false);

const overflowMenuItems = computed(() =>
  props.overflowItems.map(item => ({
    action: 'selectTab',
    value: item.key,
    label: item.name,
    isSelected: item.key === props.activeTab,
  }))
);

const isOverflowTabActive = computed(() =>
  props.overflowItems.some(item => item.key === props.activeTab)
);

const closeOverflowMenu = () => {
  showOverflowMenu.value = false;
};

const toggleOverflowMenu = () => {
  showOverflowMenu.value = !showOverflowMenu.value;
};

const onOverflowAction = ({ value }) => {
  emit('chatTabChange', value);
  closeOverflowMenu();
};
</script>

<template>
  <div class="flex items-center w-full min-w-0">
    <ChatTypeTabs
      class="min-w-0 flex-1"
      :items="items"
      :active-tab="activeTab"
      @chat-tab-change="emit('chatTabChange', $event)"
    />

    <div
      v-if="overflowMenuItems.length"
      v-on-click-outside="closeOverflowMenu"
      class="relative flex items-center flex-shrink-0 h-10 ltr:pr-3 rtl:pl-3 -mt-1"
    >
      <Button
        v-tooltip="t('IBSOFT_THEME.CONVERSATION_TABS.MORE_VIEWS')"
        type="button"
        icon="i-lucide-ellipsis"
        slate
        ghost
        xs
        :aria-label="t('IBSOFT_THEME.CONVERSATION_TABS.MORE_VIEWS')"
        :class="{ 'bg-n-alpha-1 dark:bg-n-solid-active': isOverflowTabActive }"
        @click="toggleOverflowMenu"
      />
      <DropdownMenu
        v-if="showOverflowMenu"
        :menu-items="overflowMenuItems"
        class="top-full mt-1 w-40 ltr:right-3 rtl:left-3"
        @action="onOverflowAction"
      />
    </div>
  </div>
</template>
