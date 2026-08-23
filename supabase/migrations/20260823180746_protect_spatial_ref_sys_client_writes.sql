-- Protect PostGIS spatial_ref_sys from direct client mutations.
--
-- Supabase installs this extension-owned table under supabase_admin in this
-- project, so the project postgres role cannot enable RLS or revoke the
-- original grants. This statement-level trigger blocks writes from the two
-- client-facing PostgREST roles while preserving PostGIS/internal access.

create or replace function public.prevent_spatial_ref_sys_client_writes()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if current_user in ('anon', 'authenticated') then
    raise exception 'direct client writes to spatial_ref_sys are disabled'
      using errcode = '42501';
  end if;
  return null;
end;
$$;

revoke all on function public.prevent_spatial_ref_sys_client_writes()
  from public, anon, authenticated;

drop trigger if exists protect_spatial_ref_sys_client_writes
  on public.spatial_ref_sys;

create trigger protect_spatial_ref_sys_client_writes
before insert or update or delete or truncate
on public.spatial_ref_sys
for each statement
execute function public.prevent_spatial_ref_sys_client_writes();
