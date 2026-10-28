import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase, type Ledger, type Category, type Tag } from '../lib/supabase'

export const useDataStore = defineStore('data', () => {
  const ledgers = ref<Ledger[]>([])
  const categories = ref<Category[]>([])
  const tags = ref<Tag[]>([])

  async function fetchLedgers() {
    const { data, error } = await supabase.from('ledgers').select('*').order('created_at')
    if (error) throw error
    ledgers.value = data || []
  }

  async function fetchCategories() {
    const { data, error } = await supabase.from('categories').select('*').order('sort_order')
    if (error) throw error
    categories.value = data || []
  }

  async function fetchTags() {
    const { data, error } = await supabase.from('tags').select('*').order('name')
    if (error) throw error
    tags.value = data || []
  }

  async function fetchAll() {
    await Promise.all([fetchLedgers(), fetchCategories(), fetchTags()])
  }

  async function ensureDefaultCategories() {
    if (categories.value.length > 0) return
    const defaults = [
      { name: '餐饮', type: 'expense', icon: 'Food', color: '#F0A04B', sort_order: 1 },
      { name: '交通', type: 'expense', icon: 'Van', color: '#6DAEDB', sort_order: 2 },
      { name: '购物', type: 'expense', icon: 'ShoppingBag', color: '#E08585', sort_order: 3 },
      { name: '住房', type: 'expense', icon: 'HomeFilled', color: '#A0A0A0', sort_order: 4 },
      { name: '娱乐', type: 'expense', icon: 'Film', color: '#C4A0D0', sort_order: 5 },
      { name: '医疗', type: 'expense', icon: 'FirstAidKit', color: '#7DBE7D', sort_order: 6 },
      { name: '其他支出', type: 'expense', icon: 'More', color: '#B0A993', sort_order: 99 },
      { name: '工资', type: 'income', icon: 'Wallet', color: '#46A993', sort_order: 1 },
      { name: '奖金', type: 'income', icon: 'Trophy', color: '#F0C04B', sort_order: 2 },
      { name: '投资收益', type: 'income', icon: 'TrendCharts', color: '#6DAEDB', sort_order: 3 },
      { name: '其他收入', type: 'income', icon: 'More', color: '#B0A993', sort_order: 99 },
    ]
    const { error } = await supabase.from('categories').insert(defaults)
    if (error) throw error
    await fetchCategories()
  }

  return {
    ledgers,
    categories,
    tags,
    fetchLedgers,
    fetchCategories,
    fetchTags,
    fetchAll,
    ensureDefaultCategories,
  }
})
