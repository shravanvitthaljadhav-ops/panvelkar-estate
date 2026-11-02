# Private payment portal deployment

## Files
- `payment-portal.html`: V2.0 portal UI, now uses Supabase login and server-side persistence.
- `payment-admin.html`: Super Admin-only invitation page.
- `src/payment-portal-auth.js` and `src/payment-portal-data-v6.js`: browser auth/data modules.
- Supabase tables and RPCs: migrations 001–007 have been applied to project `zawatmovyrjcpgxkqcqq`.

## Hosting target
Use Cloudflare Pages connected to this GitHub repository and branch `payments-private-staging`. Set the build command to blank and the output directory to the repository root. The portal is served at `/payment-portal.html`; admin invitations at `/payment-admin.html`.

Add the custom hostname `payments.panvelkar-estate-stanford.in`. Keep the existing main website and other subdomains unchanged.

## Mandatory outer access layer
In Cloudflare Zero Trust, create a self-hosted Access application for `payments.panvelkar-estate-stanford.in`. Add an Allow policy containing only the owner and the approved Admin email addresses. Do not use an allow-all policy. The Free Zero Trust plan currently supports up to 50 users; the society's 3–4 Admins fit within that published allowance. Check current terms before changing plans.

## Supabase Auth Hook (must be enabled before first login)
In Supabase Dashboard → Authentication → Hooks, enable the Custom Access Token Hook and select:
`private.payment_admin_access_token_hook`.

Add `https://payments.panvelkar-estate-stanford.in/payment-portal.html` to the Auth redirect allow-list. Enable leaked-password protection in Auth security settings.

The existing active super_admin profile has already been placed in the private payment Admin allow-list. The Hook is not yet enabled, so portal login is intentionally not activated until this setting is completed.

## Inviting the other Admins
After Cloudflare Access and the Auth Hook are configured, open `/payment-admin.html`, sign in with the existing active Super Admin account, and invite each Admin using their own email address. The invitation Edge Function is deployed as `payment-admin-provision`; it checks the active super_admin profile and adds the invited account to the private allow-list. Do not share passwords.

For each new Admin, add the same email to the Cloudflare Access Allow policy. Supabase login and database RLS remain a second, independent authorization layer.

## Initial V2.0 data
The one-time importer refuses to run if payment units already exist. Use the generated V2.0 JSON backup from the approved local V2.0 source only after the portal login works. It contains 428 units (414 flats and 14 shops); historical received amounts are preserved as opening receipts because the source seed has no transaction-level history. No payment dates are invented.

## Current safety status
- Migrations 001–007 applied; payment tables have RLS enabled.
- Two default templates are present.
- One existing active super_admin is in the private allow-list.
- No resident units or payment transactions have been imported yet.
- No existing ERP, RFID, Fancy Dress, main site, or other subdomain was changed.
- No paid Supabase branch was created.
- GitHub Pages is not used as the private hosting target.
