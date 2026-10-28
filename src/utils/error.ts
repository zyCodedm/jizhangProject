// 把 Supabase / 数据库返回的英文错误转成中文提示

const CJK = /[\u4e00-\u9fa5]/

const CODE_MAP: Record<string, string> = {
  // Supabase Auth
  invalid_credentials: '邮箱或密码错误',
  email_exists: '该邮箱已注册，请直接登录',
  user_already_exists: '该邮箱已注册，请直接登录',
  weak_password: '密码过于简单，请使用字母、数字和符号组合',
  email_not_confirmed: '邮箱尚未验证，请先前往邮箱完成验证',
  user_not_found: '用户不存在',
  same_password: '新密码不能与旧密码相同',
  signup_disabled: '当前系统已关闭注册',
  validation_failed: '邮箱格式不正确',
  over_email_send_rate_limit: '邮件发送过于频繁，请稍后再试',
  over_request_rate_limit: '操作过于频繁，请稍后再试',
  // 数据库
  '23505': '该数据已存在，请勿重复添加',
  '23503': '关联的数据不存在，请刷新后重试',
  '23502': '必填项不能为空',
  '42501': '没有权限执行该操作',
  PGRST301: '登录状态已失效，请重新登录',
}

const MESSAGE_RULES: Array<[RegExp, string]> = [
  [/user already registered|already been registered/, '该邮箱已注册，请直接登录'],
  [/invalid login credentials|invalid grant/, '邮箱或密码错误'],
  [/email not confirmed/, '邮箱尚未验证，请先前往邮箱完成验证'],
  [/password should be at least|password is too short/, '密码长度不足，请至少输入 6 位'],
  [/weak|easy to guess|pwned/, '密码过于简单，请使用字母、数字和符号组合'],
  [/unable to validate email|invalid email/, '邮箱格式不正确'],
  [/for security purposes|rate limit|too many requests/, '操作过于频繁，请稍后再试'],
  [/signups not allowed|signup disabled/, '当前系统已关闭注册'],
  [/user not found/, '用户不存在'],
  [/new password should be different/, '新密码不能与旧密码相同'],
  [/duplicate key/, '该数据已存在，请勿重复添加'],
  [/violates foreign key/, '关联的数据不存在，请刷新后重试'],
  [/permission denied|row-level security|not authorized/, '没有权限执行该操作'],
  [/jwt|token has expired|refresh token/, '登录状态已失效，请重新登录'],
  [/failed to fetch|network ?error|load failed|timeout/, '网络连接失败，请检查网络后重试'],
]

export function errorText(err: unknown, fallback = '操作失败'): string {
  if (!err) return fallback

  const message = typeof err === 'string' ? err : (err as any).message || ''
  const code = typeof err === 'string' ? '' : String((err as any).code || (err as any).error_code || '')

  if (code && CODE_MAP[code]) return CODE_MAP[code]
  if (message && CJK.test(message)) return message

  if (message) {
    const lower = message.toLowerCase()
    for (const [pattern, text] of MESSAGE_RULES) {
      if (pattern.test(lower)) return text
    }
  }

  return fallback
}
