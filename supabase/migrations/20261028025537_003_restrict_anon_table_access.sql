/*
# Restrict anonymous database access

1. Purpose
The accounting application requires sign-in. Anonymous visitors must not be able
to read or modify any user's financial records.

2. Modified tables
- `profiles`: remove anonymous access and keep only authenticated profile reads and self-service profile field updates
- `ledgers`, `categories`, `tags`, `bills`, `budgets`: remove all anonymous table privileges

3. Security changes
- Revoke all table privileges from `anon` on all six application tables.
- Keep the existing authenticated role grants and owner-scoped RLS policies.
- No rows are deleted and no columns or data types are changed.
*/

REVOKE ALL ON TABLE public.profiles, public.ledgers, public.categories, public.tags, public.bills, public.budgets FROM anon;

REVOKE ALL ON TABLE public.profiles FROM authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT UPDATE (display_name, avatar_url) ON TABLE public.profiles TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.ledgers, public.categories, public.tags, public.bills, public.budgets TO authenticated;
