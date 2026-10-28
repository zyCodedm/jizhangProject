<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'
import { supabase } from '../lib/supabase'
import { errorText } from '../utils/error'

const auth = useAuthStore()
const theme = useThemeStore()
const saving = ref(false)
const changingPassword = ref(false)

const profileForm = reactive({
  display_name: '',
  avatar_url: '',
})

const passwordForm = reactive({
  newPassword: '',
  confirmPassword: '',
})

async function handleUpload(file: File) {
  const user = auth.user
  if (!user) return false
  const ext = file.name.split('.').pop()
  const path = `${user.id}/avatars/${Date.now()}.${ext}`
  const { error } = await supabase.storage.from('user-assets').upload(path, file)
  if (error) {
    ElMessage.error('头像上传失败')
    return false
  }
  const { data } = supabase.storage.from('user-assets').getPublicUrl(path)
  profileForm.avatar_url = data.publicUrl
  return false
}

async function handleSaveProfile() {
  if (!profileForm.display_name.trim()) {
    ElMessage.warning('请输入昵称')
    return
  }
  saving.value = true
  try {
    await auth.updateProfile({
      display_name: profileForm.display_name.trim(),
      avatar_url: profileForm.avatar_url,
    })
    ElMessage.success('保存成功')
  } catch (err: any) {
    ElMessage.error(errorText(err, '保存失败'))
  } finally {
    saving.value = false
  }
}

async function handleChangePassword() {
  if (passwordForm.newPassword.length < 6) {
    ElMessage.warning('密码至少6位')
    return
  }
  if (passwordForm.newPassword !== passwordForm.confirmPassword) {
    ElMessage.warning('两次密码不一致')
    return
  }
  changingPassword.value = true
  try {
    await auth.changePassword(passwordForm.newPassword)
    ElMessage.success('密码修改成功')
    passwordForm.newPassword = ''
    passwordForm.confirmPassword = ''
  } catch (err: any) {
    ElMessage.error(errorText(err, '修改失败'))
  } finally {
    changingPassword.value = false
  }
}

onMounted(() => {
  if (auth.profile) {
    profileForm.display_name = auth.profile.display_name
    profileForm.avatar_url = auth.profile.avatar_url
  }
})
</script>

<template>
  <div class="page-container">
    <h1 class="page-title">个人信息</h1>

    <el-card class="profile-card">
      <div class="avatar-section">
        <el-avatar :size="80" :src="profileForm.avatar_url || undefined">
          <el-icon :size="32"><User /></el-icon>
        </el-avatar>
        <el-upload :auto-upload="true" :show-file-list="false" :before-upload="handleUpload" accept="image/*">
          <el-button plain size="small">更换头像</el-button>
        </el-upload>
      </div>

      <el-form :model="profileForm" label-position="top" style="margin-top: 24px;">
        <el-form-item label="昵称">
          <el-input v-model="profileForm.display_name" placeholder="请输入昵称" />
        </el-form-item>
        <el-form-item label="邮箱">
          <el-input :model-value="auth.user?.email" disabled />
        </el-form-item>
        <el-form-item label="角色">
          <el-tag :type="auth.isAdmin ? 'danger' : 'info'" effect="light">
            {{ auth.isAdmin ? '管理员' : '普通用户' }}
          </el-tag>
        </el-form-item>
        <el-button type="primary" :loading="saving" @click="handleSaveProfile">保存修改</el-button>
      </el-form>
    </el-card>

    <el-card class="profile-card" style="margin-top: 16px;">
      <div class="section-title">修改密码</div>
      <el-form :model="passwordForm" label-position="top">
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.newPassword" type="password" placeholder="至少6位" show-password />
        </el-form-item>
        <el-form-item label="确认新密码">
          <el-input v-model="passwordForm.confirmPassword" type="password" placeholder="再次输入新密码" show-password />
        </el-form-item>
        <el-button type="primary" :loading="changingPassword" @click="handleChangePassword">修改密码</el-button>
      </el-form>
    </el-card>

    <el-card class="profile-card" style="margin-top: 16px;">
      <div class="section-title">外观设置</div>
      <div class="theme-toggle">
        <span>深色模式</span>
        <el-switch :model-value="theme.isDark" @change="theme.toggle()" />
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.profile-card {
  padding: 8px;
  max-width: 480px;
}
.avatar-section {
  display: flex;
  align-items: center;
  gap: 16px;
}
.section-title {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 16px;
}
.theme-toggle {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 14px;
}
</style>
