-- Stanford Society ERP Phase 1: finance ledger foundation
-- Staging/development migration only. Do not apply to production without review and approval.
begin;

create table if not exists public.erp_financial_settings (
  id uuid primary key default gen_random_uuid(),
  society_id uuid references public.society(id) on delete restrict,
  interest_rate_annual numeric(7,4) not null default 0 check (interest_rate_annual >= 0 and interest_rate_annual <= 100),
  interest_method text not null default 'simple_non_compounding' check (interest_method in ('simple_non_compounding')),
  interest_start_day integer not null default 1 check (interest_start_day between 1 and 31),
  currency_code text not null default 'INR' check (currency_code = 'INR'),
  effective_from date not null default current_date,
  active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_bills (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete restrict,
  billing_month date not null,
  financial_year text not null,
  bill_number text,
  due_date date,
  status text not null default 'draft' check (status in ('draft','posted','cancelled')),
  description text,
  created_by uuid references auth.users(id) on delete set null,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_id, billing_month)
);

create table if not exists public.erp_bill_items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.erp_bills(id) on delete restrict,
  charge_type text not null check (charge_type in ('maintenance','noc','interest','penalty','repair','parking','other','credit')),
  description text not null,
  amount numeric(12,2) not null,
  service_period_start date,
  service_period_end date,
  source_reference text,
  created_at timestamptz not null default now(),
  check (amount <> 0)
);

create table if not exists public.erp_payments (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete restrict,
  payment_date date not null,
  amount numeric(12,2) not null check (amount > 0),
  payment_mode text,
  reference_number text,
  bank_narration text,
  source text not null default 'manual' check (source in ('manual','bank_import','gateway','migration')),
  import_batch_id uuid,
  status text not null default 'posted' check (status in ('pending','posted','reversed')),
  notes text,
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  reversed_at timestamptz,
  reversal_reason text
);

create table if not exists public.erp_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.erp_payments(id) on delete restrict,
  bill_item_id uuid not null references public.erp_bill_items(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (payment_id, bill_item_id)
);

create table if not exists public.erp_credits (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id) on delete restrict,
  credit_date date not null,
  amount numeric(12,2) not null check (amount > 0),
  credit_type text not null check (credit_type in ('advance','excess_payment','adjustment','waiver','refund')),
  description text not null,
  source_reference text,
  status text not null default 'available' check (status in ('available','partially_used','used','cancelled')),
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_credit_allocations (
  id uuid primary key default gen_random_uuid(),
  credit_id uuid not null references public.erp_credits(id) on delete restrict,
  bill_item_id uuid not null references public.erp_bill_items(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (credit_id, bill_item_id)
);

create table if not exists public.erp_import_batches (
  id uuid primary key default gen_random_uuid(),
  file_name text not null,
  import_type text not null check (import_type in ('bills','payments','opening_balances','bank_statement')),
  status text not null default 'preview' check (status in ('preview','validated','posted','failed','cancelled')),
  row_count integer not null default 0 check (row_count >= 0),
  success_count integer not null default 0 check (success_count >= 0),
  error_count integer not null default 0 check (error_count >= 0),
  file_hash text,
  summary jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  posted_at timestamptz
);

alter table public.erp_payments
  drop constraint if exists erp_payments_import_batch_id_fkey;
alter table public.erp_payments
  add constraint erp_payments_import_batch_id_fkey
  foreign key (import_batch_id) references public.erp_import_batches(id) on delete restrict;

create table if not exists public.erp_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists erp_bills_unit_month_idx on public.erp_bills(unit_id, billing_month desc);
create index if not exists erp_bill_items_bill_idx on public.erp_bill_items(bill_id);
create index if not exists erp_payments_unit_date_idx on public.erp_payments(unit_id, payment_date desc);
create index if not exists erp_payments_import_batch_idx on public.erp_payments(import_batch_id);
create index if not exists erp_allocations_payment_idx on public.erp_payment_allocations(payment_id);
create index if not exists erp_allocations_item_idx on public.erp_payment_allocations(bill_item_id);
create index if not exists erp_credits_unit_date_idx on public.erp_credits(unit_id, credit_date desc);
create index if not exists erp_credit_allocations_credit_idx on public.erp_credit_allocations(credit_id);
create index if not exists erp_credit_allocations_item_idx on public.erp_credit_allocations(bill_item_id);
create index if not exists erp_audit_events_entity_idx on public.erp_audit_events(entity_type, entity_id, created_at desc);

alter table public.erp_financial_settings enable row level security;
alter table public.erp_bills enable row level security;
alter table public.erp_bill_items enable row level security;
alter table public.erp_payments enable row level security;
alter table public.erp_payment_allocations enable row level security;
alter table public.erp_credits enable row level security;
alter table public.erp_credit_allocations enable row level security;
alter table public.erp_import_batches enable row level security;
alter table public.erp_audit_events enable row level security;

-- Admin and super_admin use the existing active profile role model.
create policy "erp_settings_admin_all" on public.erp_financial_settings for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));

create policy "erp_bills_admin_all" on public.erp_bills for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_bills_member_read_own" on public.erp_bills for select to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role = 'member' and p.unit_id = erp_bills.unit_id) and status = 'posted');

create policy "erp_bill_items_admin_all" on public.erp_bill_items for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_bill_items_member_read_own" on public.erp_bill_items for select to authenticated
using (exists (select 1 from public.erp_bills b join public.profiles p on p.unit_id = b.unit_id where b.id = erp_bill_items.bill_id and b.status = 'posted' and p.id = (select auth.uid()) and p.active = true and p.role = 'member'));

create policy "erp_payments_admin_all" on public.erp_payments for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_payments_member_read_own" on public.erp_payments for select to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role = 'member' and p.unit_id = erp_payments.unit_id));

create policy "erp_allocations_admin_all" on public.erp_payment_allocations for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_allocations_member_read_own" on public.erp_payment_allocations for select to authenticated
using (exists (select 1 from public.erp_payments pay join public.profiles p on p.unit_id = pay.unit_id where pay.id = erp_payment_allocations.payment_id and p.id = (select auth.uid()) and p.active = true and p.role = 'member'));

create policy "erp_credits_admin_all" on public.erp_credits for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_credits_member_read_own" on public.erp_credits for select to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role = 'member' and p.unit_id = erp_credits.unit_id));

create policy "erp_credit_allocations_admin_all" on public.erp_credit_allocations for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));
create policy "erp_credit_allocations_member_read_own" on public.erp_credit_allocations for select to authenticated
using (exists (select 1 from public.erp_credits c join public.profiles p on p.unit_id = c.unit_id where c.id = erp_credit_allocations.credit_id and p.id = (select auth.uid()) and p.active = true and p.role = 'member'));

create policy "erp_import_batches_admin_all" on public.erp_import_batches for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));

create policy "erp_audit_events_admin_all" on public.erp_audit_events for all to authenticated
using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')))
with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active = true and p.role in ('admin','super_admin')));

commit;
