# Payment portal implementation status — 2 November 2026

## Completed
- Applied migrations 001–007 to Supabase project `zawatmovyrjcpgxkqcqq`.
- Dedicated payment tables created with RLS enabled.
- Atomic payment ledger operations, audit triggers, transaction clear, outstanding updates, WhatsApp status reset/expiry, template CRUD and one-time V2.0 importer installed.
- Two V2.0 default communication templates seeded.
- Existing active super_admin account added to private payment Admin allow-list.
- Deployed Edge Function `payment-admin-provision` version 3 with JWT verification; it permits only active super_admin profile to invite/revoke Admin accounts.
- Created V2.0 frontend `payment-portal.html` with sign-in gate and Supabase-backed read/write adapter.
- Created Super Admin invitation page `payment-admin.html`.
- Browser auth and data adapter syntax checks passed.
- SQL migrations 001–005 were tested in a rollback-only transaction before application. Synthetic tests covered transaction create/update/delete, balance calculation, outstanding changes, contact/status edits, templates, audit, import and owner-only grant/revoke.
- Auth Hook function logic and grants were checked; Hook execution under the dedicated auth role could not be exercised through SQL editor. Hook enablement remains a Dashboard step.

## Live database contents after deployment
- Units: 0
- Transactions: 0
- Templates: 2
- Audit rows: 0
- Active payment Admin allow-list entries: 1 (existing active super_admin)

## Still required before operational use
1. Publish the staging branch to Cloudflare Pages and protect the hostname with Cloudflare Access.
2. Enable the Supabase Custom Access Token Hook `private.payment_admin_access_token_hook`.
3. Add the portal redirect URL in Supabase Auth settings and enable leaked-password protection.
4. Invite the remaining Admin email addresses and add those emails to the Cloudflare Access allow-list.
5. Upload the generated V2.0 JSON backup once, after login is working.
6. Perform a real browser sign-in test with the owner and one invited Admin.

No resident data has been imported, and no production website/DNS change has been made.
