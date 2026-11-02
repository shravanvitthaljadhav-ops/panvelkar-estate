-- DRAFT ONLY — DO NOT RUN AGAINST THE CONNECTED PROJECT YET.
-- V2.0 dedicated payment portal schema. This file is a review artifact on the
-- payments-private-staging branch. It has NOT been applied to Supabase.
-- It does not alter existing society/ERP/RFID/Fancy Dress tables.

begin;

-- 1) Private allow-list. This schema must not be added to the Supabase
-- Data API exposed schemas.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to supabase_auth_admin;

create table if not exists private.payment_admin_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id),
  revoked_at timestamptz,
  note text
);
alter table private.payment_admin_access enable row level security;
revoke all on private.payment_admin_access from public, anon, authenticated;
grant select on private.payment_admin_access to supabase_auth_admin;
drop policy if exists payment_auth_hook_read on private.payment_admin_access;
create policy payment_auth_hook_read on private.payment_admin_access
  for select to supabase_auth_admin using (true);

-- 2) Auth hook. Runs as invoker, not SECURITY DEFINER. The hook role has
-- narrowly scoped SELECT access above. Never authorize from user_metadata.
create or replace function private.payment_admin_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  allowed boolean := false;
  claims jsonb;
begin
  select exists (
    select 1
    from private.payment_admin_access a
    where a.user_id = (event ->> 'user_id')::uuid
      and a.active = true
  ) into allowed;

  claims := coalesce(event -> 'claims', '{}'::jsonb);
  claims := jsonb_set(claims, '{payment_admin}', to_jsonb(allowed), true);
  return jsonb_set(event, '{claims}', claims, true);
end;
$$;

revoke all on function private.payment_admin_access_token_hook(jsonb) from public, anon, authenticated;
grant execute on function private.payment_admin_access_token_hook(jsonb) to supabase_auth_admin;

-- 3) Dedicated payment tables.
create table if not exists public.payment_units (
  id uuid primary key default gen_random_uuid(),
  unit_key text not null unique,
  wing text not null,
  unit_number text not null,
  unit_type text not null default 'Flat' check (unit_type in ('Flat','Shop','Office')),
  member_name text not null default '',
  flat_status text not null default '',
  mobile_1 text,
  mobile_2 text,
  mobile_3 text,
  email text,
  other_email text,
  total_demand numeric(14,2) not null default 0 check (total_demand >= 0),
  total_received numeric(14,2) not null default 0 check (total_received >= 0),
  outstanding numeric(14,2) not null default 0 check (outstanding >= 0),
  payment_status text not null default 'Pending' check (payment_status in ('Paid','Partial','Pending')),
  whatsapp_status text not null default 'Pending' check (whatsapp_status in ('Pending','Sent','Not Required')),
  whatsapp_sent_at timestamptz,
  payment_date date,
  remarks text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.payment_units(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  payment_date date not null,
  remarks text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.payment_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'General Notice',
  message text not null,
  is_default boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.payment_portal_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.payment_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists payment_transactions_unit_date_idx
  on public.payment_transactions(unit_id, payment_date desc);
create index if not exists payment_units_wing_unit_idx
  on public.payment_units(wing, unit_number);
create index if not exists payment_units_payment_status_idx
  on public.payment_units(payment_status);

-- 4) RLS: all payment tables are Admin-only. No anon policies.
alter table public.payment_units enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.payment_templates enable row level security;
alter table public.payment_portal_settings enable row level security;
alter table public.payment_audit_log enable row level security;

drop policy if exists payment_units_admin_all on public.payment_units;
create policy payment_units_admin_all on public.payment_units
  for all to authenticated
  using (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false))
  with check (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false));

drop policy if exists payment_transactions_admin_all on public.payment_transactions;
create policy payment_transactions_admin_all on public.payment_transactions
  for all to authenticated
  using (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false))
  with check (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false));

drop policy if exists payment_templates_admin_all on public.payment_templates;
create policy payment_templates_admin_all on public.payment_templates
  for all to authenticated
  using (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false))
  with check (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false));

drop policy if exists payment_settings_admin_all on public.payment_portal_settings;
create policy payment_settings_admin_all on public.payment_portal_settings
  for all to authenticated
  using (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false))
  with check (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false));

drop policy if exists payment_audit_admin_read on public.payment_audit_log;
create policy payment_audit_admin_read on public.payment_audit_log
  for select to authenticated
  using (coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false));
drop policy if exists payment_audit_admin_insert on public.payment_audit_log;
create policy payment_audit_admin_insert on public.payment_audit_log
  for insert to authenticated
  with check (
    actor_id = (select auth.uid())
    and coalesce((select (auth.jwt() ->> 'payment_admin')::boolean), false)
  );

-- Restrict table privileges in addition to RLS. No direct client writes to
-- derived totals; future RPCs must implement atomic transaction + audit logic.
revoke all on public.payment_units, public.payment_transactions,
  public.payment_templates, public.payment_portal_settings,
  public.payment_audit_log from anon, public;
grant select, insert, update, delete on public.payment_units,
  public.payment_transactions, public.payment_templates,
  public.payment_portal_settings to authenticated;
grant select, insert on public.payment_audit_log to authenticated;
grant usage, select on sequence public.payment_audit_log_id_seq to authenticated;

-- 5) Financial status rule copied from V2.0 calcPaymentStatus():
-- demand <= 0 or outstanding <= 0 => Paid; received > 0 => Partial; else Pending.
-- Outstanding = max(demand - received, 0). Payment history remains separate.
-- NOTE: transaction write RPCs and audit triggers are intentionally not
-- included in this first schema review file; they are a separate review gate.

commit;
