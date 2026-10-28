import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase, type Profile } from '../lib/supabase'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<import('@supabase/supabase-js').User | null>(null)
  const profile = ref<Profile | null>(null)
  const loading = ref(true)
  let initPromise: Promise<void> | null = null

  const isAuthenticated = computed(() => !!user.value)
  const isAdmin = computed(() => !!profile.value?.is_admin)
  const displayName = computed(() => profile.value?.display_name || 'User')

  async function init() {
    if (initPromise) return initPromise
    initPromise = (async () => {
      loading.value = true
      const { data: { session } } = await supabase.auth.getSession()
      user.value = session?.user ?? null
      if (user.value) {
        await fetchProfile()
      }
      loading.value = false

      supabase.auth.onAuthStateChange((_event, session) => {
        user.value = session?.user ?? null
        if (user.value) {
          (async () => {
            await fetchProfile()
          })()
        } else {
          profile.value = null
        }
      })
    })()
    return initPromise
  }

  async function fetchProfile() {
    if (!user.value) return
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .maybeSingle()
    if (error) {
      console.error('Failed to fetch profile:', error.message)
      return
    }
    profile.value = data
  }

  async function signUp(email: string, password: string, displayName: string) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { display_name: displayName } },
    })
    if (error) throw error
    return data
  }

  async function signIn(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    user.value = data.user
    await fetchProfile()
    return data
  }

  async function signOut() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
    user.value = null
    profile.value = null
  }

  async function updateProfile(updates: { display_name?: string; avatar_url?: string }) {
    if (!user.value) throw new Error('Not authenticated')
    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user.value.id)
      .select()
      .maybeSingle()
    if (error) throw error
    if (data) profile.value = data
  }

  async function changePassword(newPassword: string) {
    const { error } = await supabase.auth.updateUser({ password: newPassword })
    if (error) throw error
  }

  return {
    user,
    profile,
    loading,
    isAuthenticated,
    isAdmin,
    displayName,
    init,
    fetchProfile,
    signUp,
    signIn,
    signOut,
    updateProfile,
    changePassword,
  }
})
