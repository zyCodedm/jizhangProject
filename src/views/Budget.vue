<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { supabase, type Budget } from '../lib/supabase'
import { useDataStore } from '../stores/data'
import { formatCurrency } from '../utils/format'
import dayjs from 'dayjs'

const dataStore = useDataStore()
const loading = ref(true)
const budgets = ref<Budget[]>([])
const monthExpenses = ref<Record<string, number>>({})
const currentMonth = ref(dayjs().format('YYYY-MM'))
const saving = ref(false)

const totalBudget = computed(() =>
  budgets.value.filter((b) => b.month === currentMonth.value && !b.category_id).reduce((s, b) => s + Number(b.amount), 0)
)
const totalExpense = computed(() => monthExpenses.value.total || 0)
const overallProgress = computed(() => {
  if (totalBudget.value === 0) return 0
  return Math.min((totalExpense.value / totalBudget.value) * 100, 100)
})
const isOverBudget = computed(() => totalBudget.value > 0 && totalExpense.value > totalBudget.value)

const dialogVisible = ref(false)
const form = reactive({
  id: '',
  month: dayjs().format('YYYY-MM'),
  amount: 0,
  category_id: '',
})

const monthBudgets = computed(() => budgets.value.filter((b) => b.month === currentMonth.value))

async function fetchBudgets() {
  loading.value = true
  const { data, error } = await supabase.from('budgets').select('*').order('month', { ascending: false })
  if (error) {
    ElMessage.error('加载预算失败')
    loading.value = false
    return
  }
  budgets.value = data || []
  await fetchMonthExpenses()
  loading.value = false
}

async function fetchMonthExpenses() {
  const startOfMonth = dayjs(currentMonth.value + '-01').startOf('month').format('YYYY-MM-DD')
  const endOfMonth = dayjs(currentMonth.value + '-01').endOf('month').format('YYYY-MM-DD')
  const { data, error } = await supabase
    .from('bills')
    .select('amount, category_id')
    .eq('type', 'expense')
    .gte('bill_date', startOfMonth)
    .lte('bill_date', endOfMonth)
  if (error || !data) return
  const byCategory: Record<string, number> = {}
  let total = 0
  data.forEach((b) => {
    const key = b.category_id || 'uncategorized'
    byCategory[key] = (byCategory[key] || 0) + Number(b.amount)
    total += Number(b.amount)
  })
  byCategory.total = total
  monthExpenses.value = byCategory
}

function getCategoryName(id: string | null) {
  if (!id) return '总预算'
  return dataStore.categories.find((c) => c.id === id)?.name || '未知分类'
}

function getCategoryColor(id: string | null) {
  if (!id) return '#46A993'
  return dataStore.categories.find((c) => c.id === id)?.color || '#B0A993'
}

function getExpenseForBudget(b: Budget) {
  if (b.category_id) return monthExpenses.value[b.category_id] || 0
  return monthExpenses.value['total'] || 0
}

function getProgress(b: Budget) {
  if (b.amount === 0) return 0
  return Math.min((getExpenseForBudget(b) / Number(b.amount)) * 100, 100)
}

function isOver(b: Budget) {
  return getExpenseForBudget(b) > Number(b.amount)
}

function openAdd() {
  form.id = ''
  form.month = currentMonth.value
  form.amount = 0
  form.category_id = ''
  dialogVisible.value = true
}

function openEdit(b: Budget) {
  form.id = b.id
  form.month = b.month
  form.amount = Number(b.amount)
  form.category_id = b.category_id || ''
  dialogVisible.value = true
}

async function handleSave() {
  if (form.amount <= 0) {
    ElMessage.warning('预算金额必须大于0')
    return
  }
  const conflict = budgets.value.some(
    (b) => b.id !== form.id && b.month === form.month && (b.category_id || '') === (form.category_id || '')
  )
  if (conflict) {
    ElMessage.warning(form.category_id ? '该月份此分类已设置预算' : '该月份已设置总预算')
    return
  }
  saving.value = true
  const payload = {
    month: form.month,
    amount: Number(form.amount),
    category_id: form.category_id || null,
  }
  try {
    if (form.id) {
      const { error } = await supabase.from('budgets').update(payload).eq('id', form.id)
      if (error) throw error
      ElMessage.success('修改成功')
    } else {
      const { error } = await supabase.from('budgets').insert(payload)
      if (error) throw error
      ElMessage.success('添加成功')
    }
    dialogVisible.value = false
    await fetchBudgets()
  } catch (err: any) {
    const message = err?.code === '23505' ? '该月份已存在相同分类的预算' : err?.message || '操作失败'
    ElMessage.error(message)
  } finally {
    saving.value = false
  }
}

async function handleDelete(b: Budget) {
  try {
    await ElMessageBox.confirm('确定要删除这个预算吗？', '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('budgets').delete().eq('id', b.id)
    if (error) throw error
    ElMessage.success('删除成功')
    await fetchBudgets()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(err.message || '删除失败')
  }
}

watch(currentMonth, () => {
  fetchMonthExpenses()
})

onMounted(() => {
  fetchBudgets()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1 class="page-title">预算管理</h1>
      <div class="header-actions">
        <el-date-picker v-model="currentMonth" type="month" value-format="YYYY-MM" placeholder="选择月份" />
        <el-button type="primary" @click="openAdd">
          <el-icon><Plus /></el-icon> 设置预算
        </el-button>
      </div>
    </div>

    <!-- Overall budget card -->
    <el-card class="overall-card" :class="{ over: isOverBudget }">
      <div class="overall-header">
        <span class="overall-title">{{ currentMonth }} 总预算</span>
        <el-button v-if="totalBudget > 0" text type="primary" size="small" @click="openEdit(monthBudgets.find(b => !b.category_id)!)">编辑</el-button>
      </div>
      <div class="overall-amount">
        <span class="spent">{{ formatCurrency(totalExpense) }}</span>
        <span class="budget">/ {{ formatCurrency(totalBudget) }}</span>
      </div>
      <el-progress
        :percentage="overallProgress"
        :color="isOverBudget ? '#E08585' : '#46A993'"
        :stroke-width="12"
        :show-text="false"
        style="margin-top: 12px;"
      />
      <div v-if="isOverBudget" class="over-alert">
        <el-icon><WarningFilled /></el-icon>
        已超预算 {{ formatCurrency(totalExpense - totalBudget) }}
      </div>
      <div v-else-if="totalBudget > 0" class="remaining">
        剩余 {{ formatCurrency(totalBudget - totalExpense) }}
      </div>
    </el-card>

    <!-- Category budgets -->
    <div class="category-budgets">
      <div v-for="b in monthBudgets.filter(b => b.category_id)" :key="b.id" class="cat-budget-item">
        <el-card>
          <div class="cb-header">
            <div class="cb-left">
              <span class="color-dot" :style="{ background: getCategoryColor(b.category_id) }"></span>
              <span class="cb-name">{{ getCategoryName(b.category_id) }}</span>
            </div>
            <div class="cb-actions">
              <el-button text type="primary" size="small" @click="openEdit(b)">编辑</el-button>
              <el-button text type="danger" size="small" @click="handleDelete(b)">删除</el-button>
            </div>
          </div>
          <div class="cb-amount">
            <span :style="{ color: isOver(b) ? '#E08585' : 'var(--text-primary)' }">{{ formatCurrency(getExpenseForBudget(b)) }}</span>
            <span class="cb-budget"> / {{ formatCurrency(Number(b.amount)) }}</span>
          </div>
          <el-progress
            :percentage="getProgress(b)"
            :color="isOver(b) ? '#E08585' : getCategoryColor(b.category_id)"
            :stroke-width="8"
            :show-text="false"
            style="margin-top: 8px;"
          />
          <div v-if="isOver(b)" class="over-alert small">
            <el-icon><WarningFilled /></el-icon>
            超出 {{ formatCurrency(getExpenseForBudget(b) - Number(b.amount)) }}
          </div>
        </el-card>
      </div>

      <div v-if="monthBudgets.filter(b => b.category_id).length === 0 && !loading" class="empty-state" style="grid-column: 1 / -1;">
        <el-icon class="empty-icon"><PieChart /></el-icon>
        <p>暂无分类预算，点击右上角设置</p>
      </div>
    </div>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑预算' : '设置预算'" width="420px">
      <el-form :model="form" label-position="top">
        <el-form-item label="月份" required>
          <el-date-picker v-model="form.month" type="month" value-format="YYYY-MM" style="width: 100%;" />
        </el-form-item>
        <el-form-item label="预算金额" required>
          <el-input-number v-model="form.amount" :precision="2" :min="0" :step="100" style="width: 100%;" />
        </el-form-item>
        <el-form-item label="分类（留空为总预算）">
          <el-select v-model="form.category_id" placeholder="选择分类或留空" style="width: 100%;" clearable>
            <el-option v-for="c in dataStore.categories.filter(c => c.type === 'expense')" :key="c.id" :label="c.name" :value="c.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 12px;
}
.header-actions {
  display: flex;
  gap: 8px;
  align-items: center;
}
.overall-card {
  padding: 8px;
  margin-bottom: 16px;
}
.overall-card.over {
  border-color: var(--danger) !important;
}
.overall-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.overall-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-secondary);
}
.overall-amount {
  margin-top: 8px;
}
.spent {
  font-size: 28px;
  font-weight: 600;
  color: var(--text-primary);
}
.budget {
  font-size: 16px;
  color: var(--text-tertiary);
}
.over-alert {
  margin-top: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--danger);
  font-size: 13px;
  font-weight: 500;
}
.over-alert.small {
  font-size: 12px;
  margin-top: 8px;
}
.remaining {
  margin-top: 12px;
  font-size: 13px;
  color: var(--color-primary);
}
.category-budgets {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 12px;
}
.cat-budget-item .el-card {
  padding: 4px 8px;
}
.cb-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.cb-left {
  display: flex;
  align-items: center;
  gap: 6px;
}
.cb-name {
  font-size: 14px;
  font-weight: 500;
}
.cb-actions {
  display: flex;
  gap: 2px;
}
.cb-amount {
  margin-top: 8px;
  font-size: 20px;
  font-weight: 600;
}
.cb-budget {
  font-size: 14px;
  color: var(--text-tertiary);
}
.color-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

@media (max-width: 768px) {
  .header-actions {
    width: 100%;
  }
}
</style>
