import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

export type Profile = {
  id: string
  display_name: string
  avatar_url: string
  is_admin: boolean
  created_at: string
}

export type Ledger = {
  id: string
  name: string
  initial_balance: number
  currency: string
  icon: string
  user_id: string
  created_at: string
  updated_at: string
}

export type Category = {
  id: string
  name: string
  type: 'income' | 'expense'
  icon: string
  color: string
  sort_order: number
  user_id: string
  created_at: string
}

export type Tag = {
  id: string
  name: string
  color: string
  user_id: string
  created_at: string
}

export type Bill = {
  id: string
  amount: number
  type: 'income' | 'expense' | 'transfer'
  category_id: string | null
  ledger_id: string | null
  tag_ids: string[]
  note: string
  bill_date: string
  payment_method: string
  receipt_url: string
  user_id: string
  created_at: string
  updated_at: string
  category?: Category | null
  ledger?: Ledger | null
}

export type Budget = {
  id: string
  month: string
  amount: number
  category_id: string | null
  user_id: string
  created_at: string
  updated_at: string
}
