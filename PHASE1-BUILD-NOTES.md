# Phase 1 build notes — Maintenance & Collections

This branch contains the first finance schema draft and a standalone admin UI development preview.

## Files
- `supabase/migrations/20261012_society_erp_phase1_finance.sql`: new ledger entities and RLS policies. Not applied to any database.
- `maintenance-erp-dev.html`: admin-only UI skeleton, read-only list views, local CSV preview, and interest-rate calculator. It intentionally does not post financial transactions.
- `SOCIETY-ERP-IMPLEMENTATION-PLAN.md`: phased implementation and acceptance criteria.

## Deliberate safeguards
- Production `portal.html` is unchanged.
- No migration has been applied to the live Supabase project.
- The HTML does not contain a publishable key; it will display setup guidance until configured. Never insert a service-role key into browser code.
- The UI is a development preview, not an official ledger. Posting, payment allocation, credit allocation, interest posting, and import commits remain disabled until tested transaction logic and schema constraints are reviewed.
- Existing legacy `maintenance_dues` data is not automatically transformed. A reconciliation/mapping exercise must happen before any opening balances or historical entries are imported.

## Review required before staging deployment
1. Confirm unit IDs and mapping between legacy `units` and any historical flat-master/maintenance exports.
2. Review the migration and test the role policies in a disposable Supabase branch.
3. Add the project's publishable key through a safe configuration mechanism.
4. Implement server/database-side transactional posting and duplicate import detection.
5. Add row-level test cases: member A cannot see member B's bills, items, payments, or credits.
6. Test simple interest monthly on eligible principal only; never accrue interest on previously posted interest.
7. Verify all opening balance + charges + interest - credits - payments = closing balance calculations against approved sample ledgers.
8. Obtain explicit approval before production deployment.
