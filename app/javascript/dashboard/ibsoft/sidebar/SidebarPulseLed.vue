<script setup>
defineProps({
  active: { type: Boolean, default: false },
});
</script>

<template>
  <svg
    v-if="active"
    aria-hidden="true"
    focusable="false"
    viewBox="0 0 16 16"
    class="ibsoft-sidebar-pulse-led"
  >
    <circle class="ibsoft-sidebar-pulse-led__halo" cx="8" cy="8" r="6" />
    <circle class="ibsoft-sidebar-pulse-led__core" cx="8" cy="8" r="3.2" />
  </svg>
</template>

<style scoped>
.ibsoft-sidebar-pulse-led {
  width: 0.625rem;
  height: 0.625rem;
  overflow: visible;
  pointer-events: none;
  filter: drop-shadow(0 0 0.45rem var(--ibsoft-sidebar-pulse-color));
}

.ibsoft-sidebar-pulse-led__halo {
  fill: var(--ibsoft-sidebar-pulse-color);
  opacity: 0.36;
  transform-origin: center;
  animation: ibsoft-sidebar-pulse-led 1.35s ease-in-out infinite;
}

.ibsoft-sidebar-pulse-led__core {
  fill: var(--ibsoft-sidebar-pulse-core);
  stroke: var(--ibsoft-sidebar-pulse-ring);
  stroke-width: 1.35;
}

@keyframes ibsoft-sidebar-pulse-led {
  0%,
  100% {
    opacity: 0.3;
    transform: scale(0.72);
  }

  50% {
    opacity: 0.82;
    transform: scale(1.24);
  }
}

@media (prefers-reduced-motion: reduce) {
  .ibsoft-sidebar-pulse-led__halo {
    animation: none;
    opacity: 0.56;
  }
}
</style>
