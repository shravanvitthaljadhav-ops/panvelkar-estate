# Panvelkar Estate Stanford — Private Payment Portal Staging

This branch is for the approved V2.0 payment and WhatsApp communication application only.

- Preserve the approved V2.0 interface and behavior.
- Use Supabase Auth with individual authorised Admin accounts; the number of Admins is configurable.
- Deny member and tenant roles access to this application.
- Use dedicated payment application tables and strict row-level security; do not reuse or modify unrelated RFID, Fancy Dress, member portal, or public website data paths.
- Keep secrets and real resident/payment data out of this repository.
- GitHub Pages is public/static and is not an approved private production host.
- Do not change the main branch, public website, DNS, existing applications, or production records as part of staging.

## Staging gates

1. Map V2.0 local-storage records and transaction history to a dedicated schema.
2. Review the migration and access policies before applying database changes.
3. Test multiple authorised Admin accounts, concurrent edits, transaction history, templates, imports, reports, exports, and mobile behavior.
4. Import live records only after a verified backup and explicit approval.
5. Deploy only after a private hosting/access layer and Supabase policies have been verified.

No production schema, data, account, role, DNS, or hosting changes are authorised by this branch documentation.