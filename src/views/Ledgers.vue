<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { supabase, type Ledger } from '../lib/supabase'
import { formatCurrency } from '../utils/format'
import { useDataStore } from '../stores/data'

const dataStore = useDataStore()
const loading = ref(true)
const ledgers = ref<Ledger[]>([])
const dialogVisible = ref(false)
const editing = ref(false)
const saving = ref(false)

const form = reactive({
  id: '',
  name: '',
  initial_balance: 0,
  currency: 'CNY',
  icon: 'Wallet',
})

const icons = ['Wallet', 'CreditCard', 'GoldMedal', 'Coin', 'Money', 'WalletFilled']

async function fetchLedgers() {
  loading.value = true
  const { data, error } = await supabase.from('ledgers').select('*').order('created_at')
  if (error) {
    ElMessage.error('加载账本失败')
    loading.value = false
    return
  }
  ledgers.value = data || []
  loading.value = false
}

async function fetchBalance(ledgerId: string): Promise<number> {
  const { data, error } = await supabase
    .from('bills')
    .select('amount, type')
    .eq('ledger_id', ledgerId)
  if (error || !data) return 0
  const income = data.filter((b) => b.type === 'income').reduce((s, b) => s + Number(b.amount), 0)
  const expense = data.filter((b) => b.type === 'expense').reduce((s, b) => s + Number(b.amount), 0)
  return income - expense
}

const balances = ref<Record<string, number>>({})

async function loadBalances() {
  for (const l of ledgers.value) {
    balances.value[l.id] = await fetchBalance(l.id)
  }
}

function openAdd() {
  editing.value = false
  form.id = ''
  form.name = ''
  form.initial_balance = 0
  form.currency = 'CNY'
  form.icon = 'Wallet'
  dialogVisible.value = true
}

function openEdit(ledger: Ledger) {
  editing.value = true
  form.id = ledger.id
  form.name = ledger.name
  form.initial_balance = Number(ledger.initial_balance)
  form.currency = ledger.currency
  form.icon = ledger.icon
  dialogVisible.value = true
}

async function handleSave() {
  if (!form.name.trim()) {
    ElMessage.warning('请输入账本名称')
    return
  }
  saving.value = true
  const payload = {
    name: form.name.trim(),
    initial_balance: Number(form.initial_balance),
    currency: form.currency,
    icon: form.icon,
  }
  try {
    if (editing.value) {
      const { error } = await supabase.from('ledgers').update(payload).eq('id', form.id)
      if (error) throw error
      ElMessage.success('修改成功')
    } else {
      const { error } = await supabase.from('ledgers').insert(payload)
      if (error) throw error
      ElMessage.success('添加成功')
    }
    dialogVisible.value = false
    await fetchLedgers()
    await dataStore.fetchLedgers()
    await loadBalances()
  } catch (err: any) {
    ElMessage.error(err.message || '操作失败')
  } finally {
    saving.value = false
  }
}

function getIconName(icon: string | null | undefined) {
  return icon && icons.includes(icon) ? icon : 'Wallet'
}

async function handleDelete(ledger: Ledger) {
  try {
    await ElMessageBox.confirm(`确定要删除账本「${ledger.name}」吗？该账本下的所有账单也会被删除。`, '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('ledgers').delete().eq('id', ledger.id)
    if (error) throw error
    ElMessage.success('删除成功')
    await fetchLedgers()
    await dataStore.fetchLedgers()
    await loadBalances()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(err.message || '删除失败')
  }
}

onMounted(async () => {
  await fetchLedgers()
  await loadBalances()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1 class="page-title">账本管理</h1>
      <el-button type="primary" @click="openAdd">
        <el-icon><Plus /></el-icon> 新增账本
      </el-button>
    </div>

    <div v-loading="loading" class="ledger-grid">
      <el-card v-for="ledger in ledgers" :key="ledger.id" class="ledger-card">
        <div class="ledger-top">
          <div class="ledger-icon">
            <el-icon :size="24" color="#46A993"><component :is="getIconName(ledger.icon)" /></el-icon>
          </div>
          <div class="ledger-info">
            <div class="ledger-name">{{ ledger.name }}</div>
            <div class="ledger-currency">{{ ledger.currency }}</div>
          </div>
        </div>
        <div class="ledger-balance">
          <div class="balance-label">当前余额</div>
          <div class="balance-value" :class="{ negative: (balances[ledger.id] || 0) + Number(ledger.initial_balance) < 0 }">
            {{ formatCurrency((balances[ledger.id] || 0) + Number(ledger.initial_balance)) }}
          </div>
          <div class="balance-sub">初始: {{ formatCurrency(Number(ledger.initial_balance)) }}</div>
        </div>
        <div class="ledger-actions">
          <el-button text type="primary" size="small" @click="openEdit(ledger)">编辑</el-button>
          <el-button text type="danger" size="small" @click="handleDelete(ledger)">删除</el-button>
        </div>
      </el-card>

      <div v-if="!loading && ledgers.length === 0" class="empty-state" style="grid-column: 1 / -1;">
        <el-icon class="empty-icon"><Wallet /></el-icon>
        <p>暂无账本，点击右上角新增</p>
      </div>
    </div>

    <el-dialog v-model="dialogVisible" :title="editing ? '编辑账本' : '新增账本'" width="420px">
      <el-form :model="form" label-position="top">
        <el-form-item label="账本名称" required>
          <el-input v-model="form.name" placeholder="如：日常账户、储蓄卡" />
        </el-form-item>
        <el-form-item label="初始金额">
          <el-input-number v-model="form.initial_balance" :precision="2" :step="100" style="width: 100%;" />
        </el-form-item>
        <el-form-item label="币种">
          <el-select v-model="form.currency" style="width: 100%;">
            <el-option label="人民币 CNY" value="CNY" />
            <el-option label="美元 USD" value="USD" />
            <el-option label="欧元 EUR" value="EUR" />
          </el-select>
        </el-form-item>
        <el-form-item label="图标">
          <div class="icon-picker">
            <div
              v-for="icon in icons"
              :key="icon"
              class="icon-option"
              :class="{ active: form.icon === icon }"
              @click="form.icon = icon"
            >
              <el-icon :size="20"><component :is="getIconName(icon)" /></el-icon>
            </div>
          </div>
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
}
.ledger-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 16px;
}
.ledger-card {
  padding: 8px;
}
.ledger-top {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}
.ledger-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: rgba(70, 169, 147, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
}
.ledger-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}
.ledger-currency {
  font-size: 12px;
  color: var(--text-tertiary);
}
.ledger-balance {
  padding: 12px 0;
  border-top: 1px solid var(--border-color);
  border-bottom: 1px solid var(--border-color);
  margin-bottom: 12px;
}
.balance-label {
  font-size: 12px;
  color: var(--text-tertiary);
}
.balance-value {
  font-size: 22px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 4px 0;
}
.balance-value.negative {
  color: var(--danger);
}
.balance-sub {
  font-size: 12px;
  color: var(--text-tertiary);
}
.ledger-actions {
  display: flex;
  justify-content: flex-end;
  gap: 4px;
}
.icon-picker {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.icon-option {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  border: 2px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}
.icon-option:hover {
  border-color: var(--color-primary);
}
.icon-option.active {
  border-color: var(--color-primary);
  background: rgba(70, 169, 147, 0.1);
}
</style>
