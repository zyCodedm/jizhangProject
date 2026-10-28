<script setup lang="ts">
import { onMounted } from 'vue'
import { useThemeStore } from './stores/theme'
import { useAuthStore } from './stores/auth'

const theme = useThemeStore()
const auth = useAuthStore()

onMounted(async () => {
  theme.init()
  await auth.init()
})
</script>

<template>
  <router-view />
</template>
