# Payment portal deployment — Supabase-authenticated staging

## Architecture decision
Cloudflare Zero Trust checkout is not being used because the owner does not want to add a payment method. Do not activate a paid Cloudflare product or enter card details.

Use Cloudflare Pages Free for static hosting, with Supabase Auth and database RLS as the security boundary for all payment data. The login page and static HTML/JS assets are publicly reachable; this is not a network-level private site. No resident records or secrets may be placed in static assets or the public GitHub repository.

## Hosting
- Repository: `shravanvitthaljadhav-ops/panvelkar-estate`
- Branch: `payments-private-staging`
- Build command: none
- Build output directory: repository root
- Portal path: `/payment-portal.html`
- Super Admin invitation path: `/payment-admin.html`
- Intended custom hostname: `payments.panvelkarestatestanford.in`

Create a Cloudflare Pages project from the repository and staging branch only. Do not connect the production main branch and do not alter the main website or existing DNS records. Attach only the payment subdomain to the Pages project. The Pages `*.pages.dev` preview URL is also publicly reachable, so treat it as a public login shell, never as a private network boundary.

## Authentication and data security
- Supabase project: `zawatmovyrjcpgxkqcqq`
- Supabase URL: `https://zawatmovyrjcpgxkqcqq.supabase.co`
- Browser code may contain only the Supabase publishable/anon key. Never expose a service-role or secret key.
- Supabase Custom Access Token Hook must remain enabled and point to `private.payment_admin_access_token_hook`.
- The browser auth module requires the `payment_admin=true` JWT claim before showing the portal.
- Database RLS and Admin-gated RPCs are the authoritative security boundary. Verify every payment table has RLS enabled and every write RPC checks the payment-admin claim.
- Only active Admin allow-list entries should receive the payment-admin claim.
- Do not rely on hidden UI, an unlisted URL, or the Pages hostname for security.

## Supabase Auth URL configuration
After the final custom hostname is attached, add these exact redirect URLs to Supabase Authentication URL Configuration:
- `https://payments.panvelkarestatestanford.in/payment-portal.html`
- `https://payments.panvelkarestatestanford.in/payment-admin.html`

Do not retain or use the old hyphenated hostname `payments.panvelkar-estate-stanford.in` as the production redirect.

Enable leaked-password protection in Supabase Auth security settings before issuing Admin credentials.

## Admin accounts
The existing active Super Admin is already present in the private payment Admin allow-list. No invitations have been sent yet. After staging URL and login are tested, use the Super Admin invitation page to invite each approved Admin with their own email address and password setup flow. Never share passwords or tokens in chat.

## Initial data
Do not import resident data until authentication, RLS, RPC permissions, and the full V2.0 workflow pass staging tests. The one-time importer refuses to run if payment units already exist. Use only the approved V2.0 source backup after a separate backup and owner confirmation. Historical receipts without transaction dates must remain opening receipts; do not invent dates.

## Safety constraints
- Keep V2.0 as the approved design baseline.
- Do not deploy to the main branch.
- Do not modify the main website, existing DNS records, unrelated subdomains, unrelated Supabase tables/functions, or production data.
- No resident data in GitHub.
- No card details or paid Cloudflare subscription required for this selected architecture.
- Before go-live, verify direct `pages.dev` access still shows only the login shell and that unauthenticated or non-Admin users cannot read any payment data through the Supabase API.
