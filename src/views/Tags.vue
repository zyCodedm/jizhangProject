<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { supabase, type Tag } from '../lib/supabase'
import { useDataStore } from '../stores/data'
import { errorText } from '../utils/error'

const dataStore = useDataStore()
const loading = ref(true)
const dialogVisible = ref(false)
const editing = ref(false)
const saving = ref(false)

const form = reactive({
  id: '',
  name: '',
  color: '#B0A993',
})

const colorOptions = [
  '#46A993', '#F0A04B', '#6DAEDB', '#E08585', '#C4A0D0', '#B0A993',
  '#7DBE7D', '#F0C04B', '#A0D8E8', '#D4A0A0', '#8FD4C4', '#95A5A6',
]

async function fetchTags() {
  loading.value = true
  try {
    await dataStore.fetchTags()
  } catch {
    ElMessage.error('加载标签失败')
  } finally {
    loading.value = false
  }
}

function openAdd() {
  editing.value = false
  form.id = ''
  form.name = ''
  form.color = '#B0A993'
  dialogVisible.value = true
}

function openEdit(tag: Tag) {
  editing.value = true
  form.id = tag.id
  form.name = tag.name
  form.color = tag.color
  dialogVisible.value = true
}

async function handleSave() {
  if (!form.name.trim()) {
    ElMessage.warning('请输入标签名称')
    return
  }
  saving.value = true
  const payload = { name: form.name.trim(), color: form.color }
  try {
    if (editing.value) {
      const { error } = await supabase.from('tags').update(payload).eq('id', form.id)
      if (error) throw error
      ElMessage.success('修改成功')
    } else {
      const { error } = await supabase.from('tags').insert(payload)
      if (error) throw error
      ElMessage.success('添加成功')
    }
    dialogVisible.value = false
    await fetchTags()
  } catch (err: any) {
    ElMessage.error(errorText(err, '操作失败'))
  } finally {
    saving.value = false
  }
}

async function handleDelete(tag: Tag) {
  try {
    await ElMessageBox.confirm(`确定要删除标签「${tag.name}」吗？`, '删除确认', {
      confirmButtonText: '删除',
      cancelButtonText: '取消',
      type: 'warning',
    })
    const { error } = await supabase.from('tags').delete().eq('id', tag.id)
    if (error) throw error
    ElMessage.success('删除成功')
    await fetchTags()
  } catch (err: any) {
    if (err !== 'cancel') ElMessage.error(errorText(err, '删除失败'))
  }
}

onMounted(() => {
  fetchTags()
})
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <h1 class="page-title">标签管理</h1>
      <el-button type="primary" @click="openAdd">
        <el-icon><Plus /></el-icon> 新增标签
      </el-button>
    </div>

    <el-card v-loading="loading">
      <div v-if="dataStore.tags.length === 0 && !loading" class="empty-state">
        <el-icon class="empty-icon"><PriceTag /></el-icon>
        <p>暂无标签</p>
      </div>
      <div v-else class="tag-grid">
        <div v-for="tag in dataStore.tags" :key="tag.id" class="tag-item">
          <el-tag
            :style="{ '--el-tag-bg-color': tag.color + '20', '--el-tag-border-color': tag.color + '40', '--el-tag-text-color': tag.color }"
            effect="light"
            size="large"
          >
            <span class="color-dot" :style="{ background: tag.color }"></span>
            {{ tag.name }}
          </el-tag>
          <div class="tag-actions">
            <el-button text type="primary" size="small" @click="openEdit(tag)">编辑</el-button>
            <el-button text type="danger" size="small" @click="handleDelete(tag)">删除</el-button>
          </div>
        </div>
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="editing ? '编辑标签' : '新增标签'" width="380px">
      <el-form :model="form" label-position="top">
        <el-form-item label="标签名称" required>
          <el-input v-model="form.name" placeholder="如：报销、固定支出" />
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
.tag-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}
.tag-item {
  display: flex;
  align-items: center;
  gap: 8px;
}
.tag-actions {
  display: flex;
  gap: 2px;
}
.color-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 4px;
}
.color-picker {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
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
