<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'
import { useDataStore } from '../stores/data'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const theme = useThemeStore()
const dataStore = useDataStore()

const isMobile = ref(window.innerWidth < 768)
const mobileMenuVisible = ref(false)

function handleResize() {
  isMobile.value = window.innerWidth < 768
}

window.addEventListener('resize', handleResize)

const menuItems = computed(() => {
  const items = [
    { index: '/dashboard', label: '仪表盘', icon: 'DataAnalysis' },
    { index: '/bills', label: '账单', icon: 'Tickets' },
    { index: '/ledgers', label: '账本', icon: 'Wallet' },
    { index: '/categories', label: '分类', icon: 'Grid' },
    { index: '/tags', label: '标签', icon: 'PriceTag' },
    { index: '/budget', label: '预算', icon: 'PieChart' },
    { index: '/profile', label: '我的', icon: 'User' },
  ]
  if (auth.isAdmin) {
    items.push({ index: '/admin', label: '管理后台', icon: 'Setting' })
  }
  return items
})

const activeMenu = computed(() => route.path)

function handleMenuSelect(index: string) {
  mobileMenuVisible.value = false
  router.push(index)
}

const mobileTabs = computed(() => {
  const tabs = [
    { index: '/dashboard', label: '首页', icon: 'HomeFilled' },
    { index: '/bills', label: '账单', icon: 'Tickets' },
    { index: '/budget', label: '预算', icon: 'PieChart' },
    { index: '/profile', label: '我的', icon: 'User' },
  ]
  return tabs
})

async function handleSignOut() {
  try {
    await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await auth.signOut()
    ElMessage.success('已退出登录')
    router.push('/login')
  } catch {
    // cancelled
  }
}

onMounted(async () => {
  if (auth.isAuthenticated) {
    try {
      await dataStore.fetchAll()
      await dataStore.ensureDefaultCategories()
    } catch (err: any) {
      console.error('Failed to load data:', err.message)
    }
  }
})

watch(() => auth.isAuthenticated, async (val) => {
  if (val) {
    try {
      await dataStore.fetchAll()
      await dataStore.ensureDefaultCategories()
    } catch (err: any) {
      console.error('Failed to load data:', err.message)
    }
  }
})
</script>

<template>
  <div class="layout" :class="{ mobile: isMobile }">
    <!-- Top navigation -->
    <header class="top-nav">
      <div class="top-nav-inner">
        <el-button v-if="isMobile" text circle aria-label="打开全部功能" @click="mobileMenuVisible = true">
          <el-icon :size="22"><Menu /></el-icon>
        </el-button>
        <div class="brand" @click="router.push('/dashboard')">
          <el-icon :size="24" color="#46A993"><Wallet /></el-icon>
          <span class="brand-name">轻记账</span>
        </div>
        <div class="top-nav-actions">
          <el-button text circle @click="theme.toggle()">
            <el-icon :size="20"><Sunny v-if="!theme.isDark" /><Moon v-else /></el-icon>
          </el-button>
          <el-dropdown trigger="click">
            <div class="user-chip">
              <el-avatar :size="32" :src="auth.profile?.avatar_url || undefined">
                <el-icon><User /></el-icon>
              </el-avatar>
              <span class="user-name">{{ auth.displayName }}</span>
              <el-icon><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="router.push('/profile')">个人信息</el-dropdown-item>
                <el-dropdown-item v-if="auth.isAdmin" @click="router.push('/admin')">管理后台</el-dropdown-item>
                <el-dropdown-item divided @click="handleSignOut">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>
    </header>

    <div class="layout-body">
      <!-- Sidebar (desktop) -->
      <aside v-if="!isMobile" class="sidebar">
        <el-menu :default-active="activeMenu" @select="handleMenuSelect">
          <el-menu-item v-for="item in menuItems" :key="item.index" :index="item.index">
            <el-icon><component :is="item.icon" /></el-icon>
            <span>{{ item.label }}</span>
          </el-menu-item>
        </el-menu>
      </aside>

      <!-- Main content -->
      <main class="main-content">
        <router-view />
      </main>
    </div>

    <!-- Mobile bottom tab bar -->
    <el-drawer v-model="mobileMenuVisible" title="全部功能" direction="ltr" size="78%">
      <el-menu :default-active="activeMenu" @select="handleMenuSelect">
        <el-menu-item v-for="item in menuItems" :key="item.index" :index="item.index">
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.label }}</span>
        </el-menu-item>
      </el-menu>
    </el-drawer>

    <nav v-if="isMobile" class="mobile-tabbar">
      <router-link
        v-for="tab in mobileTabs"
        :key="tab.index"
        :to="tab.index"
        class="tab-item"
        :class="{ active: route.path === tab.index }"
      >
        <el-icon :size="22"><component :is="tab.icon" /></el-icon>
        <span>{{ tab.label }}</span>
      </router-link>
    </nav>
  </div>
</template>

<style scoped>
.layout {
  min-height: 100vh;
  background: var(--bg-page);
}
.top-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--bg-card);
  border-bottom: 1px solid var(--border-color);
  transition: background 0.3s ease;
}
.top-nav-inner {
  max-width: 1200px;
  margin: 0 auto;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}
.brand {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}
.brand-name {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}
.top-nav-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.user-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 4px 12px;
  border-radius: 20px;
  transition: background 0.2s;
}
.user-chip:hover {
  background: var(--bg-subtle);
}
.user-name {
  font-size: 14px;
  color: var(--text-primary);
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.layout-body {
  display: flex;
  max-width: 1200px;
  margin: 0 auto;
}
.sidebar {
  width: 200px;
  flex-shrink: 0;
  padding: 16px 0;
  position: sticky;
  top: 56px;
  height: calc(100vh - 56px);
  overflow-y: auto;
}
.main-content {
  flex: 1;
  min-width: 0;
  padding-bottom: 0;
}
.mobile-tabbar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 60px;
  background: var(--bg-card);
  border-top: 1px solid var(--border-color);
  display: flex;
  z-index: 100;
}
.tab-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  color: var(--text-tertiary);
  text-decoration: none;
  font-size: 11px;
  transition: color 0.2s;
}
.tab-item.active {
  color: var(--color-primary);
}
.layout.mobile .main-content {
  padding-bottom: 60px;
}

@media (max-width: 768px) {
  .user-name {
    display: none;
  }
  .top-nav-inner {
    padding: 0 16px;
  }
}
</style>
