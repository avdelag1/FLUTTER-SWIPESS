-- Active lawyers may read the current legal package catalog through a narrow
-- app-facing RPC instead of broad table access.

create or replace function public.app_lawyer_service_packages()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.lawyer_users
    where user_id = v_uid and is_active = true
  ) then
    raise exception 'Active lawyer access required' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_result
  from (
    select id, name, category, price, description
    from public.legal_service_packages
    where is_active = true
    order by price asc, name asc
  ) x;
  return v_result;
end;
$$;

revoke all on function public.app_lawyer_service_packages() from public;
revoke all on function public.app_lawyer_service_packages() from anon;
grant execute on function public.app_lawyer_service_packages() to authenticated;
grant execute on function public.app_lawyer_service_packages() to service_role;
