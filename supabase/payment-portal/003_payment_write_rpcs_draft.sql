-- DRAFT ONLY — depends on schema draft 001 and trigger draft 002.
-- Not executed against Supabase. All functions are SECURITY INVOKER.

begin;
create or replace function public.payment_assert_admin()
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or coalesce((auth.jwt()->>'payment_admin')::boolean,false) is not true then
    raise exception 'Payment portal administrator access required' using errcode='42501';
  end if;
end; $$;
revoke all on function public.payment_assert_admin() from public,anon;
grant execute on function public.payment_assert_admin() to authenticated;

create or replace function public.payment_record_transaction(p_unit_id uuid,p_amount numeric,p_payment_date date,p_remarks text default '')
returns uuid language plpgsql security invoker set search_path = '' as $$
declare v_id uuid;
begin
  perform public.payment_assert_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  insert into public.payment_transactions(unit_id,amount,payment_date,remarks,created_by,updated_by)
  values(p_unit_id,p_amount,p_payment_date,coalesce(p_remarks,''),auth.uid(),auth.uid()) returning id into v_id;
  return v_id;
end; $$;
create or replace function public.payment_update_transaction(p_transaction_id uuid,p_amount numeric,p_payment_date date,p_remarks text default '')
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  if p_amount is null or p_amount<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  update public.payment_transactions set amount=p_amount,payment_date=p_payment_date,
    remarks=coalesce(p_remarks,''),updated_at=now(),updated_by=auth.uid() where id=p_transaction_id;
  if not found then raise exception 'Transaction not found'; end if;
end; $$;
create or replace function public.payment_delete_transaction(p_transaction_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  delete from public.payment_transactions where id=p_transaction_id;
  if not found then raise exception 'Transaction not found'; end if;
end; $$;
create or replace function public.payment_set_outstanding(p_unit_id uuid,p_outstanding numeric)
returns void language plpgsql security invoker set search_path = '' as $$
declare v_received numeric(14,2);
begin
  perform public.payment_assert_admin();
  if p_outstanding is null or p_outstanding<0 then raise exception 'Outstanding cannot be negative'; end if;
  select total_received into v_received from public.payment_units where id=p_unit_id for update;
  if not found then raise exception 'Unit not found'; end if;
  update public.payment_units set total_demand=v_received+p_outstanding,updated_at=now(),updated_by=auth.uid()
  where id=p_unit_id;
end; $$;
create or replace function public.payment_update_unit_contact(p_unit_id uuid,p_mobile_1 text,p_mobile_2 text,p_mobile_3 text,p_email text)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  update public.payment_units set mobile_1=nullif(trim(coalesce(p_mobile_1,'')),''),
    mobile_2=nullif(trim(coalesce(p_mobile_2,'')),''),
    mobile_3=nullif(trim(coalesce(p_mobile_3,'')),''),
    email=nullif(trim(coalesce(p_email,'')),''),updated_at=now(),updated_by=auth.uid() where id=p_unit_id;
  if not found then raise exception 'Unit not found'; end if;
end; $$;
create or replace function public.payment_update_flat_status(p_unit_id uuid,p_flat_status text)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  update public.payment_units set flat_status=nullif(trim(coalesce(p_flat_status,'')),''),
    updated_at=now(),updated_by=auth.uid() where id=p_unit_id;
  if not found then raise exception 'Unit not found'; end if;
end; $$;
create or replace function public.payment_set_whatsapp_status(p_unit_id uuid,p_status text,p_sent_at timestamptz default null)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  if p_status not in ('Pending','Sent','Not Required') then raise exception 'Invalid WhatsApp status'; end if;
  update public.payment_units set whatsapp_status=p_status,
    whatsapp_sent_at=case when p_status='Sent' then coalesce(p_sent_at,now()) else null end,
    updated_at=now(),updated_by=auth.uid() where id=p_unit_id;
  if not found then raise exception 'Unit not found'; end if;
end; $$;
create or replace function public.payment_set_active_template(p_template_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  if p_template_id is not null and not exists(select 1 from public.payment_templates where id=p_template_id and active=true)
  then raise exception 'Active template not found'; end if;
  insert into public.payment_portal_settings(setting_key,setting_value,updated_at,updated_by)
  values('active_template_id',to_jsonb(coalesce(p_template_id::text,'')),now(),auth.uid())
  on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_at=now(),updated_by=auth.uid();
end; $$;

revoke all on function public.payment_record_transaction(uuid,numeric,date,text) from public,anon;
revoke all on function public.payment_update_transaction(uuid,numeric,date,text) from public,anon;
revoke all on function public.payment_delete_transaction(uuid) from public,anon;
revoke all on function public.payment_set_outstanding(uuid,numeric) from public,anon;
revoke all on function public.payment_update_unit_contact(uuid,text,text,text,text) from public,anon;
revoke all on function public.payment_update_flat_status(uuid,text) from public,anon;
revoke all on function public.payment_set_whatsapp_status(uuid,text,timestamptz) from public,anon;
revoke all on function public.payment_set_active_template(uuid) from public,anon;
grant execute on function public.payment_record_transaction(uuid,numeric,date,text) to authenticated;
grant execute on function public.payment_update_transaction(uuid,numeric,date,text) to authenticated;
grant execute on function public.payment_delete_transaction(uuid) to authenticated;
grant execute on function public.payment_set_outstanding(uuid,numeric) to authenticated;
grant execute on function public.payment_update_unit_contact(uuid,text,text,text,text) to authenticated;
grant execute on function public.payment_update_flat_status(uuid,text) to authenticated;
grant execute on function public.payment_set_whatsapp_status(uuid,text,timestamptz) to authenticated;
grant execute on function public.payment_set_active_template(uuid) to authenticated;
commit;