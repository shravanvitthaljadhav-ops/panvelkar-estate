# Additional integration work — 2 November 2026

## Added
- One-time V2.0 importer that refuses to run if payment_units already contains data.
- Historical receipts without transaction details are retained as opening_received; transactions with missing dates are retained as opening receipts, never assigned fabricated dates.
- Owner-only payment Admin grant/revoke RPCs. These are the only SECURITY DEFINER functions in the payment portal draft; they check active super_admin in profiles before modifying the private allow-list.
- Edge Function source for super-admin-only invitation and revocation workflow. It uses the server-side service role only for Auth invitations; the browser never receives it.
- Authenticated invite workflow creates individual Supabase Auth invitations and allow-list entries. It does not support public self-registration.

## SQL validation
- Drafts 001–004 were executed inside a single explicit transaction and rolled back. This left no payment tables in the connected project.
- Synthetic test covered unit insert, transaction create/update/delete, derived balances, outstanding adjustment, contact update, flat status, WhatsApp status, template save/activate/delete and audit creation.
- Synthetic member test confirmed payment-unit RLS returns no rows and the transaction RPC rejects a non-Admin claim.
- Auth Hook role test could not be run because the SQL execution role is not permitted to SET ROLE supabase_auth_admin. Auth Hook must be enabled and validated through Supabase Auth Hooks before rollout.
- Draft 005 requires a further transaction-only test before any live migration.
