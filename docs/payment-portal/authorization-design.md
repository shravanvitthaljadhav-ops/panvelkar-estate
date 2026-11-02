# Payment portal authorization design (V2.0)

Status: design only. Not applied to Supabase.

## Decision
Use Supabase Auth individual accounts plus a database-backed custom access-token hook. The hook adds a trusted `payment_admin` claim only when the user has an active entry in a private payment-admin allow-list. Payment-table RLS checks that claim. No authorization decision is based on user-editable `user_metadata`.

This avoids the earlier draft's policy recursion risk: payment-table policies do not query the allow-list table. The allow-list is in a non-exposed `private` schema and is readable by the Auth hook role only. The hook is an invoker function, not a SECURITY DEFINER function.

## Roles and boundaries
- Each authorised person has their own Supabase Auth identity and password.
- The allow-list supports any number of Admins; there is no two-user limit.
- A member, tenant, inactive profile, or authenticated but unlisted user receives no `payment_admin=true` claim and must be denied by every payment-table policy.
- Ordinary payment Admins cannot add/remove other Admins or change their own access.
- Admin provisioning/revocation is performed only by a trusted owner-controlled backend action after verifying the caller is an existing active `super_admin` in the trusted profiles table.
- The backend service-role key remains server-side in Edge Function secrets and is never sent to the browser.
- No public sign-up. Users are invited/created by the owner-controlled provisioning action.

## Token and revocation behavior
- The custom Auth hook checks the private allow-list whenever a new access token is issued/refreshed.
- Revocation removes/deactivates the allow-list entry and revokes the user's sessions. Existing JWTs may remain valid until expiry, so configure a short access-token lifetime appropriate for the app and verify session revocation behavior before production.
- Sensitive admin changes are audited with actor, target user, action, timestamp, and reason.
- Do not rely on a browser-side role check alone; RLS is the enforcement boundary.

## Proposed private access table
Schema: `private` (not exposed through the Data API).
Columns:
- `user_id uuid primary key references auth.users(id) on delete cascade`
- `active boolean not null default true`
- `granted_by uuid references auth.users(id)`
- `granted_at timestamptz not null default now()`
- `revoked_by uuid references auth.users(id)`
- `revoked_at timestamptz`
- `note text`

Enable RLS. Permit SELECT only to `supabase_auth_admin` for the Auth hook. Revoke table access from `anon` and `authenticated`. Trusted provisioning uses server-side service-role access only.

## Auth hook behavior
- Input is the standard Auth hook event.
- Read `event.user_id`.
- Query `private.payment_admin_access` for matching `user_id` and `active=true`.
- Set a top-level trusted JWT claim `payment_admin` to boolean true/false.
- Return the event with modified claims.
- Function must be invoker (not SECURITY DEFINER), have a fixed safe search path, and execute permission granted only to `supabase_auth_admin`.
- Auth hook table access is granted narrowly to `supabase_auth_admin`; no browser role can query the allow-list.

## Payment table RLS shape
Every payment table enables RLS and has no anon policy. Authenticated policies require:
`(select auth.uid()) is not null AND coalesce((auth.jwt() ->> 'payment_admin')::boolean, false)`
Use separate SELECT / INSERT / UPDATE / DELETE policies where practical. UPDATE includes both USING and WITH CHECK. Audit log has SELECT for payment admins and INSERT only when `actor_id=(select auth.uid())`; no client UPDATE/DELETE.

## Atomic ledger rules
- Payment transactions are the source of truth for received amount.
- Transaction create/edit/delete must happen through a database transaction/RPC or trusted server operation that updates the transaction and recalculates the unit totals atomically.
- Recalculate total received from the sum of transaction amounts; outstanding from demand minus received; status from the approved V2.0 rules.
- Do not let the browser directly set derived `received`, `outstanding`, or `payment_status` fields.
- An outstanding-only edit changes total demand to received + new outstanding; it does not alter received or transaction history.
- Audit before/after values for every mutation.

## Test cases required before production
1. Anonymous user: cannot read or write any payment table.
2. Member profile: cannot read or write any payment table.
3. Tenant/inactive/unlisted account: cannot read or write any payment table.
4. Active allow-listed Admin: can perform only approved payment operations.
5. Admin cannot self-provision or grant another Admin.
6. Super Admin provisioning can add 3, 4, or more individual Admins.
7. Revoked Admin loses access after session revocation/token expiry; verify behavior on an already-open browser tab.
8. Two Admins editing different units concurrently do not overwrite each other's changes.
9. Concurrent transactions for the same unit preserve correct totals.
10. All successful changes are attributable in audit history.
11. The hook and payment tables are not accessible via anon REST endpoints.
12. Existing profiles, maintenance, RFID, Fancy Dress, and other application policies remain unchanged.

## Non-goals / safety
- No DDL or policy changes have been applied.
- Do not change existing `profiles` roles, existing payment/maintenance tables, existing Edge Functions, or existing apps.
- No paid Supabase branch or paid hosting.
- No production data import until backup, preview, and explicit approval.
