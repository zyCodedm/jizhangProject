<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { supabase, type Category } from '../lib/supabase'
import { useDataStore } from '../stores/data'

const dataStore = useDataStore()
const loading = ref(true)
const activeTab = ref<'expense' | 'income'>('expense')
const dialogVisible = ref(false)
const editing = ref(false)
const saving = ref(false)

const form = reactive({
  id: '',
  name: '',
  type: 'expense' as 'income' | 'expense',
  icon: 'More',
  color: '#46A993',
  sort_order: 0,
})

const iconOptions = [
  'Food', 'Van', 'ShoppingBag', 'HomeFilled', 'Film', 'FirstAidKit',
  'Wallet', 'Trophy', 'TrendCharts', 'Coffee', 'Gift', 'Mobile',
  'Lamp', 'Bicycle', 'Plane', 'Book', 'Monitor', 'More',
]

function getIconName(icon: string) {
  return iconOptions.includes(icon) ? icon : 'More'
}

const colorOptions = [
  '#46A993', '#F0A04B', '#6DAEDB', '#E08585', '#C4A0D0', '#B0A993',
  '#7DBE7D', '#F0C04B', '#A0D8E8', '#D4A0A0', '#8FD4C4', '#95A5A6',
]

const filteredCategories = computed(() =>
  dataStore.categories.filter((c) => c.type === activeTab.value).sort((a, b) => a.sort_order - b.sort_order)
)

async function fetchCategories() {
  loading.value = true
  try {
    await dataStore.fetchCategories()
  } catch {
    ElMessage.error('加载分类失败')
  } finally {
    loading.value = false
  }
}

function openAdd() {
  editing.value = false
  form.id = ''
  form.name = ''
  form.type = activeTab.value
  form.icon = 'More'
  form.color = '#46A993'
  form.sort_order = 0
  dialogVisible.value = true
}

function openEdit(cat: Category) {
  editing.value = true
  form.id = cat.id
  form.name = cat.name
  form.type = cat.type
  form.icon = cat.icon
  form.color = cat.color
  form.sort_order = cat.sort_order
  dialogVisible.value = true
}

async function handleSave() {
  if (!form.name.trim()) {
    ElMessage.warning('请输入分类名称')
    return
  }
  saving.value = true
  const payload = {
    name: form.name.trim(),
    type: form.type,
    icon: form.icon,
    color: form.color,
    sort_order: form.sort_order,
  }
  try {
    if (editing.value) {
      const { error } = await supabase.from('categories').update(payload).eq('id', form.id)
      if (error) throw error
      ElMessage.success('修改成功')
    } else {
      const { error } = await supabase.from('categories').insert(payload)
      if (error) throw error
      ElMessage.success('添加成功')
    }
    dialogVisible.value = false
    await fetchCategories()
  } catch (err: any) {
    ElMessage.error(err.message || '操作失败')
  } finally {
    saving.value = false
  }
}

async function handleDelete(cat: Category) {
  try {
    await ElMessageBox.confirm(`确定要删除分类「${cat.name}」吗？`, '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('categories').delete().eq('id', cat.id)
    if (error) throw error
    ElMessage.success('删除成功')
    await fetchCategories()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(err.message || '删除失败')
  }
}

onMounted(() => {
  fetchCategories()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1 class="page-title">分类管理</h1>
      <el-button type="primary" @click="openAdd">
        <el-icon><Plus /></el-icon> 新增分类
      </el-button>
    </div>

    <el-tabs v-model="activeTab" class="category-tabs">
      <el-tab-pane label="支出分类" name="expense" />
      <el-tab-pane label="收入分类" name="income" />
    </el-tabs>

    <div v-loading="loading" class="category-grid">
      <el-card v-for="cat in filteredCategories" :key="cat.id" class="category-card">
        <div class="cat-row">
          <div class="cat-icon" :style="{ background: cat.color + '20', color: cat.color }">
            <el-icon :size="20"><component :is="getIconName(cat.icon)" /></el-icon>
          </div>
          <div class="cat-name">{{ cat.name }}</div>
          <div class="cat-actions">
            <el-button text type="primary" size="small" @click="openEdit(cat)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(cat)">删除</el-button>
          </div>
        </div>
      </el-card>

      <div v-if="!loading && filteredCategories.length === 0" class="empty-state" style="grid-column: 1 / -1;">
        <el-icon class="empty-icon"><Grid /></el-icon>
        <p>暂无分类</p>
      </div>
    </div>

    <el-dialog v-model="dialogVisible" :title="editing ? '编辑分类' : '新增分类'" width="420px">
      <el-form :model="form" label-position="top">
        <el-form-item label="分类名称" required>
          <el-input v-model="form.name" placeholder="如：餐饮、交通" />
        </el-form-item>
        <el-form-item label="图标">
          <div class="icon-picker">
            <div
              v-for="icon in iconOptions"
              :key="icon"
              class="icon-option"
              :class="{ active: form.icon === icon }"
              @click="form.icon = icon"
            >
              <el-icon :size="18"><component :is="getIconName(icon)" /></el-icon>
            </div>
          </div>
        </el-form-item>
        <el-form-item label="颜色">
          <div class="color-picker">
            <div
              v-for="color in colorOptions"
              :key="color"
              class="color-option"
              :class="{ active: form.color === color }"
              :style="{ background: color }"
              @click="form.color = color"
            />
          </div>
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort_order" :min="0" :max="999" style="width: 100%;" />
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
  margin-bottom: 16px;
}
.category-tabs {
  margin-bottom: 16px;
}
.category-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 12px;
}
.category-card {
  padding: 4px 8px;
}
.cat-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.cat-icon {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.cat-name {
  flex: 1;
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}
.cat-actions {
  display: flex;
  gap: 2px;
}
.icon-picker, .color-picker {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.icon-option {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  border: 2px solid var(--border-color);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}
.icon-option:hover { border-color: var(--color-primary); }
.icon-option.active {
  border-color: var(--color-primary);
  background: rgba(70, 169, 147, 0.1);
}
.color-option {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
}
.color-option.active {
  border-color: var(--text-primary);
  transform: scale(1.15);
}
</style>
