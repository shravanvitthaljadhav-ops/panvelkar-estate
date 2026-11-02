-- DRAFT ONLY — template-library CRUD. Depends on drafts 001–003.
-- Not executed against Supabase.
begin;
create or replace function public.payment_save_template(p_template_id uuid,p_name text,p_category text,p_message text,p_file_name text default '')
returns uuid language plpgsql security invoker set search_path = '' as $$
declare v_id uuid;
begin
  perform public.payment_assert_admin();
  if nullif(trim(coalesce(p_name,'')),'') is null or nullif(trim(coalesce(p_message,'')),'') is null
  then raise exception 'Template name and message are required'; end if;
  if p_template_id is null then
    insert into public.payment_templates(name,category,message,file_name,is_default,active,created_by,updated_by)
    values(trim(p_name),coalesce(nullif(trim(p_category),''),'General Notice'),p_message,coalesce(p_file_name,''),false,true,auth.uid(),auth.uid())
    returning id into v_id;
  else
    update public.payment_templates set name=trim(p_name),category=coalesce(nullif(trim(p_category),''),'General Notice'),
      message=p_message,file_name=coalesce(p_file_name,''),updated_at=now(),updated_by=auth.uid()
    where id=p_template_id and is_default=false returning id into v_id;
    if v_id is null then raise exception 'Template not found or is a locked default'; end if;
  end if;
  return v_id;
end; $$;
create or replace function public.payment_delete_template(p_template_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform public.payment_assert_admin();
  if exists(select 1 from public.payment_templates where id=p_template_id and is_default=true)
  then raise exception 'Default templates cannot be deleted'; end if;
  delete from public.payment_templates where id=p_template_id;
  if not found then raise exception 'Template not found'; end if;
  update public.payment_portal_settings set setting_value=to_jsonb(''::text),updated_at=now(),updated_by=auth.uid()
  where setting_key='active_template_id' and setting_value=to_jsonb(p_template_id::text);
end; $$;
revoke all on function public.payment_save_template(uuid,text,text,text,text) from public,anon;
revoke all on function public.payment_delete_template(uuid) from public,anon;
grant execute on function public.payment_save_template(uuid,text,text,text,text) to authenticated;
grant execute on function public.payment_delete_template(uuid) to authenticated;
commit;