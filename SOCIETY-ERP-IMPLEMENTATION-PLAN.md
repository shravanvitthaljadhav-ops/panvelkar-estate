# Stanford Society ERP — Implementation Plan

## Goal
Extend the existing Panvelkar Estate Stanford portal into a SocietyRun-style society management ERP, in phases, without replacing the existing production portal or Supabase project.

## Guardrails
- Keep production `portal.html` unchanged until the user explicitly approves a tested release.
- Do not run production schema changes or modify live records during planning.
- Reuse existing Supabase Auth, role model, Row Level Security (RLS), unit/member data, notices, complaints, documents, vehicles, and audit log.
- Keep all financial records traceable; corrections should be auditable and should not silently overwrite historical entries.
- Never put service-role keys or other privileged credentials in client-side code or the repository.

## Phase 1 — Maintenance ledger and collections
1. Review current `maintenance_dues`, `collections`, `units`, and `audit_logs` structures and existing RLS policies.
2. Design separate records for bills/charges, receipts/payments, payment allocations, credits/advances, NOC and other charges, and non-compounding interest entries.
3. Support configurable interest rules; the society can specify rate and start/end periods. For rules requiring simple, non-compounding interest, calculate interest only on eligible principal and never add prior interest to the interest base.
4. Support month-wise flat ledger, opening balance, demand, credits, payments, adjustments, closing outstanding, and reconciliation.
5. Add admin entry and validated spreadsheet import with preview, duplicate detection, error report, and rollback-safe posting.
6. Add wing-wise and date-wise collections, outstanding ageing, receipt register, and flat-wise statement exports.
7. Add an audit trail for create/update/reversal actions and enforce role-based access with RLS.

## Phase 2 — Accounting
- Income/expense vouchers, vendor records, bank/cash books, bank reconciliation, budgets, financial-year reports, trial balance, and income/expenditure statements.
- Validate accounting treatment and statutory reports with the society accountant/auditor before using them as official books.

## Phase 3 — Resident self-service
- Residents can view only their authorized unit's bills, payments, receipts, notices, documents, and complaint status.
- Add secure downloadable statements and notification preferences.

## Phase 4 — Security and administration
- Extend existing vehicle/RFID workflows; add visitor, delivery, domestic-help, staff, tenant, parking, and NOC workflows as requirements are confirmed.

## Phase 5 — Communication and community
- Notices, events, polls, facility bookings, meeting records, and provider-based WhatsApp/SMS/email notifications.

## Initial audit findings
- GitHub repository: `shravanvitthaljadhav-ops/panvelkar-estate`.
- Existing production portal and a separate V2 review candidate are present. The V2 README explicitly says production `portal.html` remains unchanged until approval.
- Supabase project `Panvelkar Estate Stanford` is active in ap-south-1.
- Existing tables include `units`, `profiles`, `maintenance_dues`, `collections`, `society_collections`, and `audit_logs`; most listed tables have RLS enabled.
- The current `maintenance_dues` table stores unit, financial year, billing month, amount due/paid, status, due date, paid timestamp, and notes. This is not by itself a complete transaction-allocation ledger for the requested detailed reconciliation.
- Supabase performance advisors report unindexed foreign keys and RLS policy optimization findings. Review and remediate only after impact analysis and test coverage.

## Acceptance tests before release
- Existing member login, admin portal, notices, complaints, documents, vehicle registration, and current pages continue working.
- Opening balance + charges + interest - credits - payments = closing balance, with rounding rules explicitly defined.
- Interest does not compound where simple interest is configured.
- Duplicate imports do not create duplicate bills or payments.
- Partial and excess payments allocate correctly and remain traceable.
- Members cannot read another unit's financial data.
- All financial corrections are auditable.
- Test on a staging branch/site before any production release.

## Next implementation step
Build Phase 1 in isolation after reviewing the full production and staging integration points. Use a separate schema migration and staging validation; do not deploy to production without explicit release approval.
