/*
# Accounting System Schema

1. Overview
A full-featured personal accounting system with multi-user support, admin panel,
ledgers, categories, tags, bills, and budgets.

2. New Tables
- `profiles` — extends auth.users with display_name, avatar_url, is_admin flag
- `ledgers` — account books with initial balance, owned by user
- `categories` — income/expense categories with icon + color, owned by user
- `tags` — user-defined tags for bills
- `bills` — transactions (income/expense/transfer) with amount, category, ledger, tags, note, date, payment method, receipt image
- `budgets` — monthly budget per user, optionally per category

3. Security
- RLS enabled on all tables
- All tables owner-scoped via user_id DEFAULT auth.uid()
- profiles: users read own + admins read all; users update only display_name/avatar_url (column-restricted grant)
- is_admin column protected — only service_role can write it
- SECURITY DEFINER function is_current_user_admin() for policy checks
- 4 separate policies per table (select/insert/update/delete)

4. Indexes
- bills: user_id, ledger_id, category_id, date, type
- budgets: user_id + month (unique)
- ledgers, categories, tags: user_id
*/

-- ==================== PROFILES ====================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text DEFAULT '',
  avatar_url text DEFAULT '',
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE (display_name, avatar_url) ON public.profiles TO authenticated;

-- Helper function for admin checks (SECURITY DEFINER so it can read any profile)
-- Created after profiles table exists.
CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_current_user_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated;

DROP POLICY IF EXISTS "select_own_or_admin_profiles" ON public.profiles;
CREATE POLICY "select_own_or_admin_profiles" ON public.profiles FOR SELECT
  TO authenticated USING (id = auth.uid() OR public.is_current_user_admin());

DROP POLICY IF EXISTS "update_own_profile" ON public.profiles;
CREATE POLICY "update_own_profile" ON public.profiles FOR UPDATE
  TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- ==================== LEDGERS ====================
CREATE TABLE IF NOT EXISTS public.ledgers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  initial_balance numeric(14,2) NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'CNY',
  icon text DEFAULT 'wallet',
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ledgers ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.ledgers TO authenticated;

DROP POLICY IF EXISTS "select_own_ledgers" ON public.ledgers;
CREATE POLICY "select_own_ledgers" ON public.ledgers FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_ledgers" ON public.ledgers;
CREATE POLICY "insert_own_ledgers" ON public.ledgers FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_ledgers" ON public.ledgers;
CREATE POLICY "update_own_ledgers" ON public.ledgers FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_ledgers" ON public.ledgers;
CREATE POLICY "delete_own_ledgers" ON public.ledgers FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_ledgers_user_id ON public.ledgers(user_id);

-- ==================== CATEGORIES ====================
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('income', 'expense')),
  icon text NOT NULL DEFAULT 'circle',
  color text NOT NULL DEFAULT '#46A993',
  sort_order int NOT NULL DEFAULT 0,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;

DROP POLICY IF EXISTS "select_own_categories" ON public.categories;
CREATE POLICY "select_own_categories" ON public.categories FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_categories" ON public.categories;
CREATE POLICY "insert_own_categories" ON public.categories FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_categories" ON public.categories;
CREATE POLICY "update_own_categories" ON public.categories FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_categories" ON public.categories;
CREATE POLICY "delete_own_categories" ON public.categories FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);

-- ==================== TAGS ====================
CREATE TABLE IF NOT EXISTS public.tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color text NOT NULL DEFAULT '#B0A993',
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tags TO authenticated;

DROP POLICY IF EXISTS "select_own_tags" ON public.tags;
CREATE POLICY "select_own_tags" ON public.tags FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_tags" ON public.tags;
CREATE POLICY "insert_own_tags" ON public.tags FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_tags" ON public.tags;
CREATE POLICY "update_own_tags" ON public.tags FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_tags" ON public.tags;
CREATE POLICY "delete_own_tags" ON public.tags FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_tags_user_id ON public.tags(user_id);

-- ==================== BILLS ====================
CREATE TABLE IF NOT EXISTS public.bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  type text NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  ledger_id uuid REFERENCES public.ledgers(id) ON DELETE CASCADE,
  tag_ids uuid[] DEFAULT '{}',
  note text DEFAULT '',
  bill_date date NOT NULL DEFAULT CURRENT_DATE,
  payment_method text DEFAULT '',
  receipt_url text DEFAULT '',
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.bills TO authenticated;

DROP POLICY IF EXISTS "select_own_bills" ON public.bills;
CREATE POLICY "select_own_bills" ON public.bills FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_bills" ON public.bills;
CREATE POLICY "insert_own_bills" ON public.bills FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_bills" ON public.bills;
CREATE POLICY "update_own_bills" ON public.bills FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_bills" ON public.bills;
CREATE POLICY "delete_own_bills" ON public.bills FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_bills_user_id ON public.bills(user_id);
CREATE INDEX IF NOT EXISTS idx_bills_ledger_id ON public.bills(ledger_id);
CREATE INDEX IF NOT EXISTS idx_bills_category_id ON public.bills(category_id);
CREATE INDEX IF NOT EXISTS idx_bills_date ON public.bills(bill_date);
CREATE INDEX IF NOT EXISTS idx_bills_type ON public.bills(type);

-- Admin can read all bills for platform stats
DROP POLICY IF EXISTS "select_all_bills_admin" ON public.bills;
CREATE POLICY "select_all_bills_admin" ON public.bills FOR SELECT
  TO authenticated USING (public.is_current_user_admin());

-- Admin can read all ledgers
DROP POLICY IF EXISTS "select_all_ledgers_admin" ON public.ledgers;
CREATE POLICY "select_all_ledgers_admin" ON public.ledgers FOR SELECT
  TO authenticated USING (public.is_current_user_admin());

-- ==================== BUDGETS ====================
CREATE TABLE IF NOT EXISTS public.budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month text NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  category_id uuid REFERENCES public.categories(id) ON DELETE CASCADE,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.budgets TO authenticated;

DROP POLICY IF EXISTS "select_own_budgets" ON public.budgets;
CREATE POLICY "select_own_budgets" ON public.budgets FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_budgets" ON public.budgets;
CREATE POLICY "insert_own_budgets" ON public.budgets FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_budgets" ON public.budgets;
CREATE POLICY "update_own_budgets" ON public.budgets FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_budgets" ON public.budgets;
CREATE POLICY "delete_own_budgets" ON public.budgets FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_user_month_category
  ON public.budgets(user_id, month, COALESCE(category_id, '00000000-0000-0000-0000-000000000000'));

-- ==================== STORAGE BUCKET for avatars + receipts ====================
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-assets', 'user-assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can upload own assets" ON storage.objects;
CREATE POLICY "Users can upload own assets" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'user-assets' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Public can read user-assets" ON storage.objects;
CREATE POLICY "Public can read user-assets" ON storage.objects
  FOR SELECT USING (bucket_id = 'user-assets');

DROP POLICY IF EXISTS "Users can delete own assets" ON storage.objects;
CREATE POLICY "Users can delete own assets" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'user-assets' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ==================== TRIGGER: auto-create profile on signup ====================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
