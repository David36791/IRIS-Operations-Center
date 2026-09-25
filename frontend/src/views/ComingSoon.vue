<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'

const route = useRoute()
const title = computed(() => String(route.meta.title ?? 'This page'))
</script>

<template>
  <div class="page">
    <EmptyState :title="`${title} is not available`" description="This entry points at a page that has not been built." />
  </div>
</template>
