<script setup>
defineProps({
  typeDefinition: {
    type: Object,
    required: true,
  },
  imageClass: {
    type: String,
    default: 'max-h-7 max-w-full',
  },
  iconClass: {
    type: String,
    default: 'size-5',
  },
});
</script>

<template>
  <template v-if="typeDefinition.logo">
    <img
      :src="typeDefinition.logo.light"
      alt=""
      class="block object-contain dark:hidden"
      :class="imageClass"
    />
    <img
      :src="typeDefinition.logo.dark"
      alt=""
      class="hidden object-contain dark:block"
      :class="imageClass"
    />
  </template>
  <i v-else :class="[typeDefinition.icon, iconClass]" />
</template>
