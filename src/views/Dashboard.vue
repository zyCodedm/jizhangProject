<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import * as echarts from 'echarts'
import { useDataStore } from '../stores/data'
import { useThemeStore } from '../stores/theme'
import { supabase, type Bill } from '../lib/supabase'
import { formatCurrency, formatDate } from '../utils/format'
import dayjs from 'dayjs'

const dataStore = useDataStore()
const theme = useThemeStore()

const loading = ref(true)
const bills = ref<Bill[]>([])
const currentMonth = dayjs().format('YYYY-MM')

const trendChart = ref<HTMLElement>()
const pieChart = ref<HTMLElement>()
const barChart = ref<HTMLElement>()
let trendInst: echarts.ECharts | null = null
let pieInst: echarts.ECharts | null = null
let barInst: echarts.ECharts | null = null

const monthBills = computed(() =>
  bills.value.filter((b) => b.bill_date.startsWith(currentMonth))
)

const totalIncome = computed(() =>
  monthBills.value.filter((b) => b.type === 'income').reduce((s, b) => s + Number(b.amount), 0)
)
const totalExpense = computed(() =>
  monthBills.value.filter((b) => b.type === 'expense').reduce((s, b) => s + Number(b.amount), 0)
)
const balance = computed(() => totalIncome.value - totalExpense.value)

const recentBills = computed(() =>
  [...bills.value].sort((a, b) => b.bill_date.localeCompare(a.bill_date)).slice(0, 8)
)

function getCategoryName(id: string | null) {
  if (!id) return '未分类'
  const cat = dataStore.categories.find((c) => c.id === id)
  return cat?.name || '未分类'
}

function getCategoryColor(id: string | null) {
  if (!id) return '#B0A993'
  const cat = dataStore.categories.find((c) => c.id === id)
  return cat?.color || '#B0A993'
}

function getLedgerName(id: string | null) {
  if (!id) return '-'
  const ledger = dataStore.ledgers.find((l) => l.id === id)
  return ledger?.name || '-'
}

async function fetchBills() {
  loading.value = true
  const startOfMonth = dayjs().startOf('month').format('YYYY-MM-DD')
  const endOfMonth = dayjs().endOf('month').format('YYYY-MM-DD')
  const { data, error } = await supabase
    .from('bills')
    .select('*, category:categories(*), ledger:ledgers(*)')
    .gte('bill_date', startOfMonth)
    .lte('bill_date', endOfMonth)
    .order('bill_date', { ascending: false })
  if (error) {
    loading.value = false
    return
  }
  bills.value = data || []
  loading.value = false
  renderCharts()
}

function getChartTextColor() {
  return theme.isDark ? '#95A5A6' : '#636E72'
}

function renderCharts() {
  // Trend line chart - daily income/expense
  if (trendChart.value) {
    if (!trendInst) trendInst = echarts.init(trendChart.value)
    const daysInMonth = dayjs().daysInMonth()
    const days: string[] = []
    const expenseData: number[] = []
    const incomeData: number[] = []
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = dayjs().date(d).format('YYYY-MM-DD')
      days.push(`${d}`)
      const dayBills = monthBills.value.filter((b) => b.bill_date === dateStr)
      expenseData.push(dayBills.filter((b) => b.type === 'expense').reduce((s, b) => s + Number(b.amount), 0))
      incomeData.push(dayBills.filter((b) => b.type === 'income').reduce((s, b) => s + Number(b.amount), 0))
    }
    trendInst.setOption({
      tooltip: { trigger: 'axis' },
      legend: {
        data: ['支出', '收入'],
        bottom: 0,
        textStyle: { color: getChartTextColor() },
      },
      grid: { left: '3%', right: '4%', bottom: '12%', top: '5%', containLabel: true },
      xAxis: { type: 'category', data: days, axisLabel: { color: getChartTextColor(), fontSize: 11 }, axisLine: { lineStyle: { color: '#E4E9E7' } } },
      yAxis: { type: 'value', axisLabel: { color: getChartTextColor(), fontSize: 11 }, splitLine: { lineStyle: { color: theme.isDark ? '#353C3B' : '#EEF2F0' } } },
      series: [
        { name: '支出', type: 'line', smooth: true, data: expenseData, itemStyle: { color: '#F0A04B' }, areaStyle: { color: 'rgba(240,160,75,0.1)' } },
        { name: '收入', type: 'line', smooth: true, data: incomeData, itemStyle: { color: '#46A993' }, areaStyle: { color: 'rgba(70,169,147,0.1)' } },
      ],
    })
  }

  // Expense pie chart
  if (pieChart.value) {
    if (!pieInst) pieInst = echarts.init(pieChart.value)
    const expenseByCategory: Record<string, number> = {}
    monthBills.value.filter((b) => b.type === 'expense').forEach((b) => {
      const key = b.category_id || 'uncategorized'
      expenseByCategory[key] = (expenseByCategory[key] || 0) + Number(b.amount)
    })
    const pieData = Object.entries(expenseByCategory).map(([key, val]) => ({
      name: getCategoryName(key === 'uncategorized' ? null : key),
      value: val,
      itemStyle: { color: getCategoryColor(key === 'uncategorized' ? null : key) },
    }))
    pieInst.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
      series: [{
        type: 'pie',
        radius: ['45%', '70%'],
        center: ['50%', '45%'],
        data: pieData.length ? pieData : [{ name: '暂无数据', value: 1, itemStyle: { color: '#E4E9E7' } }],
        label: { color: getChartTextColor(), fontSize: 11 },
        labelLine: { lineStyle: { color: getChartTextColor() } },
        itemStyle: { borderRadius: 6, borderColor: theme.isDark ? '#252B2A' : '#fff', borderWidth: 2 },
      }],
    })
  }

  // Income bar chart
  if (barChart.value) {
    if (!barInst) barInst = echarts.init(barChart.value)
    const incomeByCategory: Record<string, number> = {}
    monthBills.value.filter((b) => b.type === 'income').forEach((b) => {
      const key = b.category_id || 'uncategorized'
      incomeByCategory[key] = (incomeByCategory[key] || 0) + Number(b.amount)
    })
    const barData = Object.entries(incomeByCategory).map(([key, val]) => ({
      name: getCategoryName(key === 'uncategorized' ? null : key),
      value: val,
      itemStyle: { color: getCategoryColor(key === 'uncategorized' ? null : key) },
    }))
    barInst.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: '3%', right: '4%', bottom: '3%', top: '8%', containLabel: true },
      xAxis: { type: 'category', data: barData.map((d) => d.name), axisLabel: { color: getChartTextColor(), fontSize: 11, rotate: barData.length > 4 ? 20 : 0 }, axisLine: { lineStyle: { color: '#E4E9E7' } } },
      yAxis: { type: 'value', axisLabel: { color: getChartTextColor(), fontSize: 11 }, splitLine: { lineStyle: { color: theme.isDark ? '#353C3B' : '#EEF2F0' } } },
      series: [{ type: 'bar', data: barData, barWidth: '40%', itemStyle: { borderRadius: [6, 6, 0, 0] } }],
    })
  }
}

function handleResize() {
  trendInst?.resize()
  pieInst?.resize()
  barInst?.resize()
}

watch(() => theme.isDark, () => {
  renderCharts()
})

onMounted(async () => {
  await fetchBills()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  trendInst?.dispose()
  pieInst?.dispose()
  barInst?.dispose()
})
</script>

<template>
  <div class="page-container">
    <h1 class="page-title">仪表盘 · {{ currentMonth }}</h1>

    <!-- Summary cards -->
    <div v-if="loading" class="summary-grid">
      <div v-for="i in 3" :key="i" class="skeleton-card">
        <div class="skeleton-line" style="height: 14px; width: 60%; margin-bottom: 12px;"></div>
        <div class="skeleton-line" style="height: 28px; width: 40%;"></div>
      </div>
    </div>
    <div v-else class="summary-grid">
      <el-card class="summary-card income">
        <div class="summary-label">
          <el-icon><Top /></el-icon>
          <span>本月收入</span>
        </div>
        <div class="summary-value">{{ formatCurrency(totalIncome) }}</div>
      </el-card>
      <el-card class="summary-card expense">
        <div class="summary-label">
          <el-icon><Bottom /></el-icon>
          <span>本月支出</span>
        </div>
        <div class="summary-value">{{ formatCurrency(totalExpense) }}</div>
      </el-card>
      <el-card class="summary-card balance">
        <div class="summary-label">
          <el-icon><Wallet /></el-icon>
          <span>本月结余</span>
        </div>
        <div class="summary-value" :class="{ negative: balance < 0 }">{{ formatCurrency(balance) }}</div>
      </el-card>
    </div>

    <!-- Charts -->
    <el-card style="margin-top: 16px;">
      <div class="chart-title">收支日趋势</div>
      <div ref="trendChart" style="height: 280px;"></div>
    </el-card>

    <div class="chart-grid">
      <el-card>
        <div class="chart-title">支出分类</div>
        <div ref="pieChart" style="height: 280px;"></div>
      </el-card>
      <el-card>
        <div class="chart-title">收入分类</div>
        <div ref="barChart" style="height: 280px;"></div>
      </el-card>
    </div>

    <!-- Recent bills -->
    <el-card style="margin-top: 16px;">
      <div class="chart-title">最近账单</div>
      <div v-if="recentBills.length === 0" class="empty-state">
        <el-icon class="empty-icon"><Tickets /></el-icon>
        <p>暂无账单记录</p>
      </div>
      <div v-else class="bill-list">
        <div v-for="bill in recentBills" :key="bill.id" class="bill-item">
          <div class="bill-left">
            <div class="bill-dot" :style="{ background: getCategoryColor(bill.category_id) }"></div>
            <div>
              <div class="bill-name">{{ getCategoryName(bill.category_id) }}</div>
              <div class="bill-meta">{{ formatDate(bill.bill_date) }} · {{ getLedgerName(bill.ledger_id) }}</div>
            </div>
          </div>
          <div class="bill-amount" :class="bill.type">
            {{ bill.type === 'income' ? '+' : bill.type === 'expense' ? '-' : '' }}{{ formatCurrency(Number(bill.amount)) }}
          </div>
        </div>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}
.skeleton-card {
  background: var(--bg-card);
  border-radius: var(--radius-card);
  padding: 24px;
  border: 1px solid var(--border-color);
}
.summary-card {
  padding: 8px 0;
}
.summary-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 12px;
}
.summary-value {
  font-size: 26px;
  font-weight: 600;
  color: var(--text-primary);
}
.summary-value.negative {
  color: var(--danger);
}
.summary-card.income .summary-label { color: var(--color-primary); }
.summary-card.expense .summary-label { color: var(--color-accent-orange); }
.chart-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 16px;
}
.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-top: 16px;
}
.bill-list {
  display: flex;
  flex-direction: column;
}
.bill-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid var(--border-color);
}
.bill-item:last-child {
  border-bottom: none;
}
.bill-left {
  display: flex;
  align-items: center;
  gap: 12px;
}
.bill-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.bill-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}
.bill-meta {
  font-size: 12px;
  color: var(--text-tertiary);
  margin-top: 2px;
}
.bill-amount {
  font-size: 15px;
  font-weight: 600;
}
.bill-amount.income { color: var(--color-primary); }
.bill-amount.expense { color: var(--color-accent-orange); }
.bill-amount.transfer { color: var(--text-secondary); }

@media (max-width: 768px) {
  .summary-grid {
    grid-template-columns: 1fr;
  }
  .chart-grid {
    grid-template-columns: 1fr;
  }
  .summary-value {
    font-size: 22px;
  }
}
</style>
