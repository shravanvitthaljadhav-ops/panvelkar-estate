-- DRAFT ONLY — review and test before applying to Supabase.
-- Depends on 001_payment_portal_schema_draft.sql.
-- Not executed against any database.

begin;
alter table public.payment_units
  add column if not exists opening_received numeric(14,2) not null default 0,
  add column if not exists opening_received_note text;
alter table public.payment_templates add column if not exists file_name text;
alter table public.payment_units add constraint payment_units_opening_received_nonnegative
  check (opening_received >= 0) not valid;

create or replace function public.payment_recalculate_unit(p_unit_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_opening numeric(14,2); v_demand numeric(14,2); v_received numeric(14,2);
  v_latest_date date; v_latest_remarks text; v_outstanding numeric(14,2); v_status text;
begin
  select u.opening_received, u.total_demand into v_opening, v_demand
  from public.payment_units u where u.id = p_unit_id for update;
  if not found then return; end if;
  select coalesce(sum(t.amount),0),
    (array_agg(t.payment_date order by t.payment_date desc,t.created_at desc))[1],
    (array_agg(t.remarks order by t.payment_date desc,t.created_at desc))[1]
  into v_received,v_latest_date,v_latest_remarks
  from public.payment_transactions t where t.unit_id=p_unit_id;
  v_received := coalesce(v_opening,0)+coalesce(v_received,0);
  v_outstanding := greatest(coalesce(v_demand,0)-v_received,0);
  if coalesce(v_demand,0)<=0 or v_outstanding<=0 then v_status:='Paid';
  elsif v_received>0 then v_status:='Partial'; else v_status:='Pending'; end if;
  update public.payment_units set total_received=v_received,outstanding=v_outstanding,
    payment_status=v_status,payment_date=coalesce(v_latest_date,payment_date),
    remarks=coalesce(v_latest_remarks,remarks),
    whatsapp_status=case when v_outstanding<=0 then 'Not Required'
      when whatsapp_status='Not Required' then 'Pending' else whatsapp_status end,
    whatsapp_sent_at=case when v_outstanding<=0 then null else whatsapp_sent_at end,
    updated_at=now(),updated_by=auth.uid() where id=p_unit_id;
end; $$;

create or replace function public.payment_units_guard_derived_fields()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_ledger numeric(14,2); v_latest_date date; v_latest_remarks text;
begin
  select coalesce(sum(t.amount),0),
    (array_agg(t.payment_date order by t.payment_date desc,t.created_at desc))[1],
    (array_agg(t.remarks order by t.payment_date desc,t.created_at desc))[1]
  into v_ledger,v_latest_date,v_latest_remarks
  from public.payment_transactions t where t.unit_id=new.id;
  new.opening_received:=greatest(coalesce(new.opening_received,0),0);
  new.total_received:=new.opening_received+coalesce(v_ledger,0);
  new.outstanding:=greatest(coalesce(new.total_demand,0)-new.total_received,0);
  new.payment_status:=case when coalesce(new.total_demand,0)<=0 or new.outstanding<=0 then 'Paid'
    when new.total_received>0 then 'Partial' else 'Pending' end;
  if v_latest_date is not null then new.payment_date:=v_latest_date;
    new.remarks:=coalesce(v_latest_remarks,new.remarks); end if;
  if new.outstanding<=0 then new.whatsapp_status:='Not Required'; new.whatsapp_sent_at:=null;
  elsif new.whatsapp_status='Not Required' then new.whatsapp_status:='Pending'; end if;
  new.updated_at:=now(); new.updated_by:=auth.uid(); return new;
end; $$;
drop trigger if exists payment_units_guard_derived_fields on public.payment_units;
create trigger payment_units_guard_derived_fields before insert or update on public.payment_units
for each row execute function public.payment_units_guard_derived_fields();

create or replace function public.payment_transactions_recalculate_parent()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op='DELETE' then perform public.payment_recalculate_unit(old.unit_id); return old;
  elsif tg_op='UPDATE' then
    if old.unit_id is distinct from new.unit_id then perform public.payment_recalculate_unit(old.unit_id); end if;
    perform public.payment_recalculate_unit(new.unit_id); return new;
  else perform public.payment_recalculate_unit(new.unit_id); return new; end if;
end; $$;
drop trigger if exists payment_transactions_recalculate_parent on public.payment_transactions;
create trigger payment_transactions_recalculate_parent after insert or update or delete
on public.payment_transactions for each row execute function public.payment_transactions_recalculate_parent();

create or replace function public.payment_audit_row_change()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_old jsonb; v_new jsonb; v_id uuid;
begin
  if tg_op<>'INSERT' then v_old:=to_jsonb(old); end if;
  if tg_op<>'DELETE' then v_new:=to_jsonb(new); end if;
  v_id:=coalesce((v_new->>'id')::uuid,(v_old->>'id')::uuid);
  insert into public.payment_audit_log(actor_id,action,entity_type,entity_id,before_data,after_data)
  values(auth.uid(),tg_op,tg_table_name,v_id,v_old,v_new);
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;

drop trigger if exists payment_units_audit on public.payment_units;
create trigger payment_units_audit after insert or update or delete on public.payment_units
for each row execute function public.payment_audit_row_change();
drop trigger if exists payment_transactions_audit on public.payment_transactions;
create trigger payment_transactions_audit after insert or update or delete on public.payment_transactions
for each row execute function public.payment_audit_row_change();
drop trigger if exists payment_templates_audit on public.payment_templates;
create trigger payment_templates_audit after insert or update or delete on public.payment_templates
for each row execute function public.payment_audit_row_change();
drop trigger if exists payment_settings_audit on public.payment_portal_settings;
create trigger payment_settings_audit after insert or update or delete on public.payment_portal_settings
for each row execute function public.payment_audit_row_change();

revoke all on function public.payment_recalculate_unit(uuid) from public,anon;
grant execute on function public.payment_recalculate_unit(uuid) to authenticated;
revoke all on function public.payment_units_guard_derived_fields() from public,anon;
revoke all on function public.payment_transactions_recalculate_parent() from public,anon;
revoke all on function public.payment_audit_row_change() from public,anon;
commit;