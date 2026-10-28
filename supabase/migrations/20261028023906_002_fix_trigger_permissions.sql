/*
# Fix handle_new_user trigger function permissions

1. Problem
- handle_new_user() is a SECURITY DEFINER function that was callable by anon and authenticated roles
- This is a trigger function and should NOT be directly callable by any client
- The security advisor flagged this as a risk

2. Changes
- Revoke EXECUTE from PUBLIC, anon, and authenticated on handle_new_user()
- This prevents direct RPC calls while keeping the trigger working (triggers run with owner privileges)
- No data changes, no policy changes
*/

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
