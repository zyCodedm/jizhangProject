<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import type { Ledger, Category, Tag } from '../lib/supabase'

const formRef = ref<FormInstance>()

defineProps<{
  form: {
    amount: number
    type: 'income' | 'expense' | 'transfer'
    category_id: string
    ledger_id: string
    tag_ids: string[]
    note: string
    bill_date: string
    payment_method: string
    receipt_url: string
  }
  rules: FormRules
  categories: Category[]
  ledgers: Ledger[]
  tags: Tag[]
  editing: boolean
}>()

const emit = defineEmits<{
  upload: [file: File]
}>()

function handleUpload(file: File): false {
  if (!file.type.startsWith('image/')) {
    ElMessage.warning('请选择图片文件')
    return false
  }
  if (file.size > 5 * 1024 * 1024) {
    ElMessage.warning('小票图片不能超过 5MB')
    return false
  }
  emit('upload', file)
  return false
}

defineExpose({
  validate: async (): Promise<boolean> => {
    if (!formRef.value) return false
    return await formRef.value.validate()
  },
})
</script>

<template>
  <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
    <el-form-item label="收支类型" prop="type">
      <el-radio-group v-model="form.type" size="default">
        <el-radio-button value="expense">支出</el-radio-button>
        <el-radio-button value="income">收入</el-radio-button>
        <el-radio-button value="transfer">转账</el-radio-button>
      </el-radio-group>
    </el-form-item>
    <el-form-item label="金额" prop="amount">
      <el-input-number v-model="form.amount" :precision="2" :min="0" :step="100" style="width: 100%;" size="large" />
    </el-form-item>
    <el-form-item v-if="form.type !== 'transfer'" label="分类" prop="category_id">
      <el-select v-model="form.category_id" placeholder="请选择分类" style="width: 100%;" clearable>
        <el-option v-for="c in categories" :key="c.id" :value="c.id">
          <span style="display: flex; align-items: center; gap: 6px;">
            <span class="color-dot" :style="{ background: c.color }"></span>
            {{ c.name }}
          </span>
        </el-option>
      </el-select>
    </el-form-item>
    <el-form-item label="账本" prop="ledger_id">
      <el-select v-model="form.ledger_id" placeholder="请选择账本" style="width: 100%;">
        <el-option v-for="l in ledgers" :key="l.id" :label="l.name" :value="l.id" />
      </el-select>
    </el-form-item>
    <el-form-item label="日期" prop="bill_date">
      <el-date-picker
        v-model="form.bill_date"
        type="date"
        value-format="YYYY-MM-DD"
        placement="bottom-start"
        popper-class="bill-date-popper"
        style="width: 100%;"
      />
    </el-form-item>
    <el-form-item label="支付方式">
      <el-select v-model="form.payment_method" placeholder="选择支付方式" style="width: 100%;" clearable>
        <el-option label="微信" value="微信" />
        <el-option label="支付宝" value="支付宝" />
        <el-option label="银行卡" value="银行卡" />
        <el-option label="现金" value="现金" />
        <el-option label="信用卡" value="信用卡" />
        <el-option label="其他" value="其他" />
      </el-select>
    </el-form-item>
    <el-form-item label="标签">
      <el-select v-model="form.tag_ids" multiple placeholder="选择标签" style="width: 100%;" clearable>
        <el-option v-for="t in tags" :key="t.id" :label="t.name" :value="t.id" />
      </el-select>
    </el-form-item>
    <el-form-item label="备注">
      <el-input v-model="form.note" type="textarea" :rows="2" placeholder="添加备注..." />
    </el-form-item>
    <el-form-item label="小票图片">
      <el-upload
        :auto-upload="true"
        :show-file-list="false"
        :before-upload="handleUpload"
        accept="image/*"
      >
        <el-button plain>
          <el-icon><Upload /></el-icon> 上传小票
        </el-button>
        <template v-if="form.receipt_url">
          <el-image :src="form.receipt_url" style="width: 80px; height: 80px; margin-left: 12px; border-radius: 8px;" fit="cover" />
        </template>
      </el-upload>
    </el-form-item>
  </el-form>
</template>

<style scoped>
.color-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
</style>
