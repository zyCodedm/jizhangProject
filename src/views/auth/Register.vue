<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../../stores/auth'
import { errorText } from '../../utils/error'

const router = useRouter()
const auth = useAuthStore()

const formRef = ref()
const loading = ref(false)
const form = reactive({
  displayName: '',
  email: '',
  password: '',
  confirmPassword: '',
})

const rules = {
  displayName: [{ required: true, message: '请输入昵称', trigger: 'blur' }],
  email: [
    { required: true, message: '请输入邮箱', trigger: 'blur' },
    { type: 'email' as const, message: '邮箱格式不正确', trigger: 'blur' },
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码至少6位', trigger: 'blur' },
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (_rule: any, value: string, callback: any) => {
        if (value !== form.password) callback(new Error('两次密码不一致'))
        else callback()
      },
      trigger: 'blur',
    },
  ],
}

async function handleSubmit() {
  await formRef.value?.validate(async (valid: boolean) => {
    if (!valid) return
    loading.value = true
    try {
      await auth.signUp(form.email, form.password, form.displayName)
      ElMessage.success('注册成功，请登录')
      router.push('/login')
    } catch (err: any) {
      ElMessage.error(errorText(err, '注册失败'))
    } finally {
      loading.value = false
    }
  })
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-header">
        <div class="auth-logo">
          <el-icon :size="32" color="#46A993"><Wallet /></el-icon>
        </div>
        <h1>创建账号</h1>
        <p>开始记录你的每一笔收支</p>
      </div>
      <el-form ref="formRef" :model="form" :rules="rules" label-position="top" @submit.prevent="handleSubmit">
        <el-form-item label="昵称" prop="displayName">
          <el-input v-model="form.displayName" placeholder="请输入昵称" size="large" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" placeholder="请输入邮箱" size="large" />
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input v-model="form.password" type="password" placeholder="至少6位" size="large" show-password />
        </el-form-item>
        <el-form-item label="确认密码" prop="confirmPassword">
          <el-input v-model="form.confirmPassword" type="password" placeholder="再次输入密码" size="large" show-password @keyup.enter="handleSubmit" />
        </el-form-item>
        <el-button type="primary" size="large" :loading="loading" style="width: 100%; margin-top: 8px;" @click="handleSubmit">
          注册
        </el-button>
      </el-form>
      <div class="auth-footer">
        已有账号？<router-link to="/login">返回登录</router-link>
      </div>
    </div>
  </div>
</template>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-page);
  padding: 20px;
}
.auth-card {
  width: 100%;
  max-width: 400px;
  background: var(--bg-card);
  border-radius: var(--radius-card);
  padding: 40px 32px;
  box-shadow: var(--shadow-card);
}
.auth-header {
  text-align: center;
  margin-bottom: 32px;
}
.auth-logo {
  width: 64px;
  height: 64px;
  border-radius: 16px;
  background: rgba(70, 169, 147, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
}
.auth-header h1 {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 4px;
}
.auth-header p {
  font-size: 13px;
  color: var(--text-tertiary);
}
.auth-footer {
  text-align: center;
  margin-top: 24px;
  font-size: 13px;
  color: var(--text-tertiary);
}
.auth-footer a {
  color: var(--color-primary);
  text-decoration: none;
  font-weight: 500;
}
</style>
