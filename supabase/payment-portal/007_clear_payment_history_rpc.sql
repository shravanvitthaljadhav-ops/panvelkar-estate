-- Payment history clear operation; one atomic transaction per unit.
begin;
create or replace function public.payment_clear_unit_transactions(p_unit_id uuid)
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_count integer;
begin
 perform public.payment_assert_admin();
 if not exists(select 1 from public.payment_units where id=p_unit_id) then raise exception 'Unit not found'; end if;
 delete from public.payment_transactions where unit_id=p_unit_id;
 get diagnostics v_count=row_count;
 return v_count;
end; $$;
revoke all on function public.payment_clear_unit_transactions(uuid) from public,anon;
grant execute on function public.payment_clear_unit_transactions(uuid) to authenticated;
commit;