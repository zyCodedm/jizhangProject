<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { supabase, type Profile } from '../lib/supabase'
import { formatCurrency, formatDateTime } from '../utils/format'

const loading = ref(true)
const users = ref<(Profile & { email?: string })[]>([])
const stats = ref({
  totalUsers: 0,
  totalBills: 0,
  totalIncome: 0,
  totalExpense: 0,
})

async function fetchAdminData() {
  loading.value = true
  const [profilesRes, billsRes] = await Promise.all([
    supabase.from('profiles').select('*').order('created_at', { ascending: false }),
    supabase.from('bills').select('amount, type'),
  ])

  if (profilesRes.error) {
    ElMessage.error('加载用户列表失败')
    loading.value = false
    return
  }

  users.value = (profilesRes.data || []) as (Profile & { email?: string })[]

  const bills = billsRes.data || []
  stats.value = {
    totalUsers: users.value.length,
    totalBills: bills.length,
    totalIncome: bills.filter((b) => b.type === 'income').reduce((s, b) => s + Number(b.amount), 0),
    totalExpense: bills.filter((b) => b.type === 'expense').reduce((s, b) => s + Number(b.amount), 0),
  }
  loading.value = false
}

onMounted(() => {
  fetchAdminData()
})
</script>

<template>
  <div class="page-container">
    <h1 class="page-title">管理后台</h1>

    <!-- Platform stats -->
    <div class="stats-grid">
      <el-card class="stat-card">
        <div class="stat-label">总用户数</div>
        <div class="stat-value">{{ stats.totalUsers }}</div>
      </el-card>
      <el-card class="stat-card">
        <div class="stat-label">总账单数</div>
        <div class="stat-value">{{ stats.totalBills }}</div>
      </el-card>
      <el-card class="stat-card">
        <div class="stat-label">平台总收入</div>
        <div class="stat-value" style="color: var(--color-primary);">{{ formatCurrency(stats.totalIncome) }}</div>
      </el-card>
      <el-card class="stat-card">
        <div class="stat-label">平台总支出</div>
        <div class="stat-value" style="color: var(--color-accent-orange);">{{ formatCurrency(stats.totalExpense) }}</div>
      </el-card>
    </div>

    <!-- Users table -->
    <el-card style="margin-top: 16px;">
      <div class="table-title">用户列表</div>
      <el-table v-loading="loading" :data="users" stripe style="width: 100%;">
        <el-table-column label="用户" min-width="160">
          <template #default="{ row }">
            <div style="display: flex; align-items: center; gap: 8px;">
              <el-avatar :size="32" :src="row.avatar_url || undefined">
                <el-icon><User /></el-icon>
              </el-avatar>
              <span>{{ row.display_name }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="角色" width="100">
          <template #default="{ row }">
            <el-tag :type="row.is_admin ? 'danger' : 'info'" size="small" effect="light">
              {{ row.is_admin ? '管理员' : '用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="注册时间" width="180">
          <template #default="{ row }">{{ formatDateTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>

      <div v-if="!loading && users.length === 0" class="empty-state">
        <el-icon class="empty-icon"><User /></el-icon>
        <p>暂无用户</p>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}
.stat-card {
  padding: 8px;
}
.stat-label {
  font-size: 13px;
  color: var(--text-secondary);
}
.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  margin-top: 8px;
}
.table-title {
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 16px;
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  .stat-value {
    font-size: 20px;
  }
}
</style>
