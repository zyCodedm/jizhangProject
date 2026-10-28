<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { supabase, type Bill } from '../lib/supabase'
import { useDataStore } from '../stores/data'
import { formatCurrency } from '../utils/format'
import { errorText } from '../utils/error'
import BillForm from '../components/BillForm.vue'
import dayjs from 'dayjs'

const dataStore = useDataStore()
const router = useRouter()

const loading = ref(true)
const bills = ref<Bill[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(20)
const selectedIds = ref<string[]>([])

const filters = reactive({
  dateRange: [] as string[],
  ledger_id: '',
  type: '',
  category_id: '',
  tag_id: '',
  minAmount: '' as string | number,
  maxAmount: '' as string | number,
  keyword: '',
})

const isMobile = ref(window.innerWidth < 768)
window.addEventListener('resize', () => { isMobile.value = window.innerWidth < 768 })

const dialogVisible = ref(false)
const editing = ref(false)
const saving = ref(false)
const billForm = reactive({
  id: '',
  amount: 0,
  type: 'expense' as 'income' | 'expense' | 'transfer',
  category_id: '',
  ledger_id: '',
  tag_ids: [] as string[],
  note: '',
  bill_date: dayjs().format('YYYY-MM-DD'),
  payment_method: '',
  receipt_url: '',
})

const formRef = ref<{ validate: () => Promise<boolean> }>()

const billRules = {
  amount: [{ required: true, message: '请输入金额', trigger: 'blur' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }],
  ledger_id: [{ required: true, message: '请选择账本', trigger: 'change' }],
  bill_date: [{ required: true, message: '请选择日期', trigger: 'change' }],
}

const filteredCategories = computed(() =>
  dataStore.categories.filter((c) => c.type === billForm.type)
)

const mobileStartDate = computed({
  get: () => filters.dateRange[0] || '',
  set: (value: string) => {
    filters.dateRange = value ? [value, filters.dateRange[1] || ''] : []
  },
})

const mobileEndDate = computed({
  get: () => filters.dateRange[1] || '',
  set: (value: string) => {
    filters.dateRange = value ? [filters.dateRange[0] || '', value] : [filters.dateRange[0] || '']
  },
})

function getCategoryName(id: string | null) {
  if (!id) return '未分类'
  return dataStore.categories.find((c) => c.id === id)?.name || '未分类'
}

function getCategoryColor(id: string | null) {
  if (!id) return '#B0A993'
  return dataStore.categories.find((c) => c.id === id)?.color || '#B0A993'
}

function getLedgerName(id: string | null) {
  if (!id) return '-'
  return dataStore.ledgers.find((l) => l.id === id)?.name || '-'
}

function getTagName(id: string) {
  return dataStore.tags.find((t) => t.id === id)?.name || ''
}

async function fetchBills() {
  loading.value = true
  let query = supabase
    .from('bills')
    .select('*, category:categories(*), ledger:ledgers(*)', { count: 'exact' })

  if (filters.dateRange && filters.dateRange.length === 2) {
    query = query.gte('bill_date', filters.dateRange[0]).lte('bill_date', filters.dateRange[1])
  }
  if (filters.ledger_id) query = query.eq('ledger_id', filters.ledger_id)
  if (filters.type) query = query.eq('type', filters.type)
  if (filters.category_id) query = query.eq('category_id', filters.category_id)
  if (filters.tag_id) query = query.contains('tag_ids', [filters.tag_id])
  if (filters.minAmount !== '' && filters.minAmount !== undefined) query = query.gte('amount', Number(filters.minAmount))
  if (filters.maxAmount !== '' && filters.maxAmount !== undefined) query = query.lte('amount', Number(filters.maxAmount))
  if (filters.keyword) query = query.ilike('note', `%${filters.keyword}%`)

  query = query.order('bill_date', { ascending: false }).order('created_at', { ascending: false })
    .range((page.value - 1) * pageSize.value, page.value * pageSize.value - 1)

  const { data, count, error } = await query
  if (error) {
    ElMessage.error('加载账单失败')
    loading.value = false
    return
  }
  bills.value = data || []
  total.value = count || 0
  loading.value = false
}

function handleSearch() {
  page.value = 1
  fetchBills()
}

function handleReset() {
  filters.dateRange = []
  filters.ledger_id = ''
  filters.type = ''
  filters.category_id = ''
  filters.tag_id = ''
  filters.minAmount = ''
  filters.maxAmount = ''
  filters.keyword = ''
  page.value = 1
  fetchBills()
}

function openAdd() {
  if (dataStore.ledgers.length === 0) {
    ElMessage.warning('请先创建一个账本')
    router.push('/ledgers')
    return
  }
  editing.value = false
  billForm.id = ''
  billForm.amount = 0
  billForm.type = 'expense'
  billForm.category_id = ''
  billForm.ledger_id = dataStore.ledgers[0]?.id || ''
  billForm.tag_ids = []
  billForm.note = ''
  billForm.bill_date = dayjs().format('YYYY-MM-DD')
  billForm.payment_method = ''
  billForm.receipt_url = ''
  dialogVisible.value = true
}

function openEdit(bill: Bill) {
  editing.value = true
  billForm.id = bill.id
  billForm.amount = Number(bill.amount)
  billForm.type = bill.type
  billForm.category_id = bill.category_id || ''
  billForm.ledger_id = bill.ledger_id || ''
  billForm.tag_ids = bill.tag_ids || []
  billForm.note = bill.note
  billForm.bill_date = bill.bill_date
  billForm.payment_method = bill.payment_method
  billForm.receipt_url = bill.receipt_url
  dialogVisible.value = true
}

async function handleSave() {
  let valid = false
  try {
    valid = !!(await formRef.value?.validate())
  } catch {
    valid = false
  }
  if (!valid) return
  saving.value = true
  const payload = {
      amount: Number(billForm.amount),
      type: billForm.type,
      category_id: billForm.category_id || null,
      ledger_id: billForm.ledger_id || null,
      tag_ids: billForm.tag_ids,
      note: billForm.note,
      bill_date: billForm.bill_date,
      payment_method: billForm.payment_method,
      receipt_url: billForm.receipt_url,
    }
  try {
    if (editing.value) {
        const { error } = await supabase.from('bills').update(payload).eq('id', billForm.id)
        if (error) throw error
        ElMessage.success('修改成功')
    } else {
      const { error } = await supabase.from('bills').insert(payload)
      if (error) throw error
      ElMessage.success('添加成功')
    }
    dialogVisible.value = false
    await fetchBills()
  } catch (err: any) {
    ElMessage.error(errorText(err, '操作失败'))
  } finally {
    saving.value = false
  }
}

async function handleDelete(bill: Bill) {
  try {
    await ElMessageBox.confirm('确定要删除这条账单吗？', '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('bills').delete().eq('id', bill.id)
    if (error) throw error
    ElMessage.success('删除成功')
    await fetchBills()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(errorText(err, '删除失败'))
  }
}

async function handleBatchDelete() {
  if (selectedIds.value.length === 0) {
    ElMessage.warning('请先选择要删除的账单')
    return
  }
  try {
    await ElMessageBox.confirm(`确定要删除选中的 ${selectedIds.value.length} 条账单吗？`, '批量删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('bills').delete().in('id', selectedIds.value)
    if (error) throw error
    ElMessage.success(`已删除 ${selectedIds.value.length} 条账单`)
    selectedIds.value = []
    await fetchBills()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(errorText(err, '删除失败'))
  }
}

function handleSelectionChange(rows: Bill[]) {
  selectedIds.value = rows.map((r) => r.id)
}

function handleMobileSelect(id: string, checked: boolean) {
  if (checked) {
    if (!selectedIds.value.includes(id)) selectedIds.value.push(id)
  } else {
    selectedIds.value = selectedIds.value.filter((x) => x !== id)
  }
}

function handlePageChange(p: number) {
  page.value = p
  fetchBills()
}

async function uploadReceipt(file: File) {
  const user = (await supabase.auth.getUser()).data.user
  if (!user) return
  const ext = file.name.split('.').pop()
  const path = `${user.id}/receipts/${Date.now()}.${ext}`
  const { error } = await supabase.storage.from('user-assets').upload(path, file)
  if (error) {
    ElMessage.error('图片上传失败')
    return false
  }
  const { data } = supabase.storage.from('user-assets').getPublicUrl(path)
  billForm.receipt_url = data.publicUrl
  return false
}

function exportCSV() {
  const headers = ['日期', '类型', '分类', '金额', '账本', '标签', '备注', '支付方式']
  const rows = bills.value.map((b) => [
    b.bill_date,
    b.type === 'income' ? '收入' : b.type === 'expense' ? '支出' : '转账',
    getCategoryName(b.category_id),
    b.amount,
    getLedgerName(b.ledger_id),
    (b.tag_ids || []).map(getTagName).join(';'),
    b.note,
    b.payment_method,
  ])
  const csv = [headers, ...rows].map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `bills_${dayjs().format('YYYYMMDD_HHmm')}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

onMounted(async () => {
  try {
    await dataStore.fetchLedgers()
  } catch {
    ElMessage.error('加载账本失败')
  }
  await fetchBills()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1 class="page-title">账单管理</h1>
      <div class="header-actions">
        <el-button @click="exportCSV" :disabled="bills.length === 0">
          <el-icon><Download /></el-icon> 导出CSV
        </el-button>
        <el-button type="danger" plain @click="handleBatchDelete" :disabled="selectedIds.length === 0">
          <el-icon><Delete /></el-icon> 批量删除 ({{ selectedIds.length }})
        </el-button>
        <el-button type="primary" @click="openAdd">
          <el-icon><Plus /></el-icon> 新增账单
        </el-button>
      </div>
    </div>

    <!-- Filters -->
    <el-card class="filter-card">
      <div class="filter-grid">
        <el-date-picker
          v-if="!isMobile"
          v-model="filters.dateRange"
          type="daterange"
          range-separator="至"
          start-placeholder="开始日期"
          end-placeholder="结束日期"
          value-format="YYYY-MM-DD"
          popper-class="bill-date-popper"
          size="default"
        />
        <div v-else class="mobile-date-range">
          <el-date-picker
            v-model="mobileStartDate"
            type="date"
            placeholder="开始日期"
            value-format="YYYY-MM-DD"
            popper-class="bill-date-popper"
            size="default"
          />
          <span class="mobile-date-separator">至</span>
          <el-date-picker
            v-model="mobileEndDate"
            type="date"
            placeholder="结束日期"
            value-format="YYYY-MM-DD"
            popper-class="bill-date-popper"
            size="default"
          />
        </div>
        <el-select v-model="filters.ledger_id" placeholder="账本" clearable size="default">
          <el-option v-for="l in dataStore.ledgers" :key="l.id" :label="l.name" :value="l.id" />
        </el-select>
        <el-select v-model="filters.type" placeholder="收支类型" clearable size="default">
          <el-option label="收入" value="income" />
          <el-option label="支出" value="expense" />
          <el-option label="转账" value="transfer" />
        </el-select>
        <el-select v-model="filters.category_id" placeholder="分类" clearable size="default">
          <el-option v-for="c in dataStore.categories" :key="c.id" :label="c.name" :value="c.id" />
        </el-select>
        <el-select v-model="filters.tag_id" placeholder="标签" clearable size="default">
          <el-option v-for="t in dataStore.tags" :key="t.id" :label="t.name" :value="t.id" />
        </el-select>
        <el-input v-model="filters.minAmount" placeholder="最小金额" type="number" size="default" style="width: 100px;" />
        <el-input v-model="filters.maxAmount" placeholder="最大金额" type="number" size="default" style="width: 100px;" />
        <el-input v-model="filters.keyword" placeholder="备注关键词" clearable size="default" style="width: 160px;" />
        <div class="filter-actions">
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleReset">重置</el-button>
        </div>
      </div>
    </el-card>

    <!-- Bills table (desktop) -->
    <el-card v-if="!isMobile" style="margin-top: 16px;">
      <el-table
        v-loading="loading"
        :data="bills"
        stripe
        @selection-change="handleSelectionChange"
        style="width: 100%;"
      >
        <el-table-column type="selection" width="40" />
        <el-table-column label="日期" prop="bill_date" width="110" />
        <el-table-column label="类型" width="80">
          <template #default="{ row }">
            <el-tag :type="row.type === 'income' ? 'success' : row.type === 'expense' ? 'warning' : 'info'" size="small" effect="light">
              {{ row.type === 'income' ? '收入' : row.type === 'expense' ? '支出' : '转账' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="分类" width="120">
          <template #default="{ row }">
            <div style="display: flex; align-items: center;">
              <span class="color-dot" :style="{ background: getCategoryColor(row.category_id) }"></span>
              {{ getCategoryName(row.category_id) }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="金额" width="120">
          <template #default="{ row }">
            <span :style="{ color: row.type === 'income' ? '#46A993' : row.type === 'expense' ? '#F0A04B' : '#636E72', fontWeight: 600 }">
              {{ row.type === 'income' ? '+' : row.type === 'expense' ? '-' : '' }}{{ formatCurrency(Number(row.amount)) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="账本" width="100">
          <template #default="{ row }">{{ getLedgerName(row.ledger_id) }}</template>
        </el-table-column>
        <el-table-column label="标签" min-width="120">
          <template #default="{ row }">
            <el-tag v-for="tid in (row.tag_ids || [])" :key="tid" size="small" effect="plain" style="margin-right: 4px;">
              {{ getTagName(tid) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="备注" min-width="120">
          <template #default="{ row }">
            <span style="color: var(--text-secondary);">{{ row.note }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="openEdit(row)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div v-if="!loading && bills.length === 0" class="empty-state">
        <el-icon class="empty-icon"><Tickets /></el-icon>
        <p>暂无账单，点击右上角新增</p>
      </div>

      <div v-if="total > pageSize" style="margin-top: 16px; display: flex; justify-content: center;">
        <el-pagination
          layout="prev, pager, next"
          :total="total"
          :page-size="pageSize"
          :current-page="page"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- Bills card list (mobile) -->
    <div v-else style="margin-top: 16px;">
      <div v-loading="loading" class="mobile-bill-list">
        <div v-for="row in bills" :key="row.id" class="mobile-bill-card">
          <div class="mbc-left">
            <el-checkbox
              :model-value="selectedIds.includes(row.id)"
              @change="(v) => handleMobileSelect(row.id, v)"
              class="mbc-check"
            />
            <span class="mbc-color-dot" :style="{ background: getCategoryColor(row.category_id) }"></span>
          </div>
          <div class="mbc-body">
            <div class="mbc-row-top">
              <div class="mbc-cat">{{ getCategoryName(row.category_id) }}</div>
              <div
                class="mbc-amount"
                :style="{ color: row.type === 'income' ? '#46A993' : row.type === 'expense' ? '#F0A04B' : '#636E72' }"
              >
                {{ row.type === 'income' ? '+' : row.type === 'expense' ? '-' : '' }}{{ formatCurrency(Number(row.amount)) }}
              </div>
            </div>
            <div class="mbc-row-sub">
              <el-tag
                :type="row.type === 'income' ? 'success' : row.type === 'expense' ? 'warning' : 'info'"
                size="small"
                effect="light"
                style="margin-right: 6px;"
              >
                {{ row.type === 'income' ? '收入' : row.type === 'expense' ? '支出' : '转账' }}
              </el-tag>
              <span class="mbc-date">{{ row.bill_date }}</span>
              <span class="mbc-ledger">· {{ getLedgerName(row.ledger_id) }}</span>
            </div>
            <div v-if="row.note" class="mbc-note">{{ row.note }}</div>
            <div v-if="row.tag_ids?.length" class="mbc-tags">
              <el-tag v-for="tid in row.tag_ids" :key="tid" size="small" effect="plain" style="margin-right: 4px;">
                {{ getTagName(tid) }}
              </el-tag>
            </div>
          </div>
          <div class="mbc-actions">
            <el-button text type="primary" size="small" @click="openEdit(row)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </div>
        </div>

        <div v-if="!loading && bills.length === 0" class="empty-state">
          <el-icon class="empty-icon"><Tickets /></el-icon>
          <p>暂无账单，点击右上角新增</p>
        </div>
      </div>

      <div v-if="total > pageSize" style="margin-top: 16px; display: flex; justify-content: center;">
        <el-pagination
          layout="prev, pager, next"
          :total="total"
          :page-size="pageSize"
          :current-page="page"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Add/Edit Dialog -->
    <el-dialog
      v-model="dialogVisible"
      class="bill-dialog"
      :title="editing ? '编辑账单' : '新增账单'"
      :width="isMobile ? 'calc(100vw - 24px)' : '500px'"
      top="6vh"
      destroy-on-close
    >
      <BillForm
        ref="formRef"
        :form="billForm"
        :rules="billRules"
        :categories="filteredCategories"
        :ledgers="dataStore.ledgers"
        :tags="dataStore.tags"
        :editing="editing"
        @upload="uploadReceipt"
      />
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
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 12px;
}
.header-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.filter-card {
  margin-bottom: 0;
}
:deep(.bill-dialog .el-dialog__body) {
  max-height: calc(100vh - 220px);
  overflow-y: auto;
}
.filter-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
}
.filter-actions {
  display: flex;
  gap: 10px;
}
.filter-actions .el-button {
  margin-left: 0;
}

/* Mobile bill card list */
.mobile-bill-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.mobile-bill-card {
  display: flex;
  align-items: stretch;
  gap: 10px;
  background: var(--el-bg-color);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 10px;
  padding: 12px 14px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
  transition: box-shadow 0.15s;
}
.mobile-bill-card:active {
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}
.mbc-left {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  flex-shrink: 0;
}
.mbc-check {
  margin-right: 0 !important;
}
.mbc-color-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
}
.mbc-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
  overflow: hidden;
}
.mbc-row-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}
.mbc-cat {
  font-weight: 600;
  font-size: 15px;
  color: var(--el-text-color-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mbc-amount {
  font-weight: 700;
  font-size: 16px;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}
.mbc-row-sub {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
.mbc-date {
  font-variant-numeric: tabular-nums;
}
.mbc-ledger {
  color: var(--el-text-color-placeholder);
}
.mbc-note {
  font-size: 13px;
  color: var(--el-text-color-regular);
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.mbc-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.mbc-actions {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-end;
  gap: 4px;
  flex-shrink: 0;
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    align-items: stretch;
  }
  .header-actions {
    justify-content: flex-end;
  }
  .filter-grid {
    flex-direction: column;
    align-items: stretch;
  }
  .filter-grid > .el-date-editor,
  .filter-grid > .mobile-date-range,
  .filter-grid > .el-select,
  .filter-grid > .el-input {
    width: 100% !important;
    max-width: 100% !important;
    min-width: 0 !important;
  }
  .filter-grid > .el-date-editor .el-range-input {
    min-width: 0;
  }
  .mobile-date-range {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
  }
  .mobile-date-range .el-date-editor {
    flex: 1;
    min-width: 0;
    width: auto !important;
  }
  .mobile-date-separator {
    flex: 0 0 auto;
    color: var(--text-secondary);
  }
  .filter-actions {
    width: 100%;
  }
  .filter-actions .el-button {
    flex: 1;
  }
  :deep(.bill-dialog .el-dialog__body) {
    max-height: calc(100vh - 180px);
    padding: 16px;
  }
}
</style>
