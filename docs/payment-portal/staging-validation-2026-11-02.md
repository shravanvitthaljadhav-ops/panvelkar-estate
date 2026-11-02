# Payment Portal staging validation — 2 November 2026

## Completed in staging branch
- V2.0 schema draft (001), unchanged as the approved UI/behavior baseline.
- Ledger integrity and audit trigger draft (002).
- Atomic write RPC draft (003).
- Corrected V2.0 data adapter (other_email, file_name, historical opening receipts, WhatsApp status, template selection, pagination).
- Static JavaScript and SQL-contract checks.

## Financial integrity design
- Historical received amounts without trustworthy transaction rows are stored as opening_received plus an explanatory note. No synthetic payment date is created.
- Current receipts are summed from payment_transactions.
- total_received = opening_received + sum(transactions).
- outstanding = max(total_demand - total_received, 0).
- Payment status preserves V2.0 rules: Paid when demand <= 0 or outstanding <= 0; Partial when received > 0; otherwise Pending.
- Editing outstanding changes demand to received + requested outstanding; receipts and transaction history remain unchanged.
- Transaction create/edit/delete recalculates the parent unit in the same database transaction.
- WhatsApp status becomes Not Required when fully paid; outstanding units retain their existing Sent/Pending state except Not Required resets to Pending.

## Security design
- Dedicated payment_admin claim from a private allow-list via Supabase Auth Hook.
- No public signup and no member-role access.
- Payment functions are SECURITY INVOKER; table RLS remains mandatory.
- Every payment data/configuration mutation is audited with actor ID.
- No service-role key in browser code.
- Admin provisioning/revocation remains an owner-only backend task and is not yet implemented.

## Validation performed
- Node syntax parse passed for the new browser adapter.
- Static checks passed for required ledger, audit and RPC contracts.
- Static check confirms the payment SQL drafts introduce no SECURITY DEFINER functions.
- Existing V2.0 source confirms template library fields include fileName and source wing labels include R1-A and R1-B.

## Not performed / blockers
- No SQL was applied to Supabase.
- No Auth Hook was enabled.
- No real admin accounts were provisioned.
- No resident/member data was imported.
- No browser end-to-end or live RLS test was run.
- No hosting, DNS, or production deployment was changed.
- The trigger/RPC SQL still requires PostgreSQL execution testing in an isolated disposable database. In particular, trigger interaction with RLS, the Supabase Auth Hook role grants, and template/settings CRUD must be integration-tested before any live migration.
- Free Supabase database branching was declined due to hourly cost. No paid branch was created.

## Important implementation caveat
The draft uses SECURITY INVOKER trigger functions. The transaction-trigger recalculation updates the parent payment_units row and inserts audit rows; this depends on the caller's payment_admin JWT claim and the corresponding RLS policies being active. Test with an authorized payment Admin and an ordinary member/anonymous session before rollout.
