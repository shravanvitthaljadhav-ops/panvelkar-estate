-- DRAFT ONLY — initial import and default templates. Depends on drafts 001–004.
-- Import is one-time only and refuses to run if payment_units is not empty.
begin;

create or replace function public.payment_import_v20(p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare r jsonb; tx jsonb; v_unit_id uuid; v_count integer:=0; v_tx_count integer:=0;
  v_opening numeric(14,2); v_tx_opening numeric(14,2); v_has_tx boolean;
  v_flat text; v_unit_key text; v_date date;
begin
  perform public.payment_assert_admin();
  if jsonb_typeof(p_rows)<>'array' then raise exception 'Import payload must be a JSON array'; end if;
  if exists(select 1 from public.payment_units limit 1) then
    raise exception 'Import blocked: payment portal already contains units. Use a reviewed reconciliation process.';
  end if;
  for r in select value from jsonb_array_elements(p_rows) loop
    v_flat:=coalesce(r->>'flat',r->>'masterUnit','');
    v_unit_key:=coalesce(nullif(r->>'masterUnit',''),v_flat);
    if nullif(trim(v_unit_key),'') is null then raise exception 'Import row is missing flat/unit key'; end if;
    v_has_tx:=jsonb_typeof(r->'transactions')='array' and jsonb_array_length(r->'transactions')>0;
    v_opening:=case when v_has_tx then 0 else greatest(coalesce(nullif(r->>'received','')::numeric,0),0) end;
    v_tx_opening:=0;
    if v_has_tx then
      for tx in select value from jsonb_array_elements(r->'transactions') loop
        if nullif(tx->>'date','') is null then
          v_tx_opening:=v_tx_opening+greatest(coalesce(nullif(tx->>'amount','')::numeric,0),0);
        else
          v_date:=(tx->>'date')::date;
        end if;
      end loop;
    end if;
    insert into public.payment_units(unit_key,wing,unit_number,unit_type,member_name,flat_status,
      mobile_1,mobile_2,mobile_3,email,other_email,total_demand,opening_received,opening_received_note,
      whatsapp_status,whatsapp_sent_at,payment_date,remarks)
    values(v_unit_key,coalesce(r->>'wing',''),coalesce(r->>'flat',''),case when lower(coalesce(r->>'unitType','flat'))='shop' then 'Shop' when lower(coalesce(r->>'unitType','flat'))='office' then 'Office' else 'Flat' end,
      coalesce(r->>'name',''),coalesce(r->>'flatStatus',''),nullif(r->>'phone',''),
      nullif(r#>>'{phones,0}',''),nullif(r#>>'{phones,1}',''),nullif(r->>'email',''),nullif(r->>'otherEmail',''),
      greatest(coalesce(nullif(r->>'due','')::numeric,0),0),v_opening+v_tx_opening,
      case when v_opening+v_tx_opening>0 then 'Legacy opening received amount retained; no payment date fabricated.' else null end,
      case when coalesce(r->>'wa','Pending') in ('Pending','Sent','Not Required') then r->>'wa' else 'Pending' end,
      case when nullif(r->>'waSentAt','') is not null then to_timestamp((r->>'waSentAt')::numeric/1000.0) else null end,
      nullif(r->>'paymentDate','')::date,nullif(r->>'remarks',''))
    returning id into v_unit_id;
    if v_has_tx then
      for tx in select value from jsonb_array_elements(r->'transactions') loop
        if nullif(tx->>'date','') is not null then
          insert into public.payment_transactions(unit_id,amount,payment_date,remarks,created_by,updated_by)
          values(v_unit_id,(tx->>'amount')::numeric,(tx->>'date')::date,coalesce(tx->>'remarks',''),auth.uid(),auth.uid());
          v_tx_count:=v_tx_count+1;
        end if;
      end loop;
    end if;
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('units_imported',v_count,'transactions_imported',v_tx_count);
end; $$;

-- Owner-only allow-list management. SECURITY DEFINER is restricted to these
-- two functions; the caller must be an active super_admin in public.profiles.
create or replace function public.payment_admin_grant(p_user_id uuid,p_note text default '')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='super_admin' and p.active=true)
  then raise exception 'Only an active super administrator can grant payment portal access' using errcode='42501'; end if;
  insert into private.payment_admin_access(user_id,active,granted_by,granted_at,revoked_by,revoked_at,note)
  values(p_user_id,true,auth.uid(),now(),null,null,nullif(trim(coalesce(p_note,'')),''))
  on conflict(user_id) do update set active=true,granted_by=auth.uid(),granted_at=now(),revoked_by=null,revoked_at=null,note=excluded.note;
end; $$;
create or replace function public.payment_admin_revoke(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='super_admin' and p.active=true)
  then raise exception 'Only an active super administrator can revoke payment portal access' using errcode='42501'; end if;
  update private.payment_admin_access set active=false,revoked_by=auth.uid(),revoked_at=now() where user_id=p_user_id;
  if not found then raise exception 'Payment administrator entry not found'; end if;
end; $$;
revoke all on function public.payment_import_v20(jsonb) from public,anon;
grant execute on function public.payment_import_v20(jsonb) to authenticated;
revoke all on function public.payment_admin_grant(uuid,text) from public,anon;
revoke all on function public.payment_admin_revoke(uuid) from public,anon;
grant execute on function public.payment_admin_grant(uuid,text) to authenticated;
grant execute on function public.payment_admin_revoke(uuid) to authenticated;
commit;