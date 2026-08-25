create or replace function public.admin_platform_usage()
returns jsonb
language plpgsql
security definer
set search_path = public, storage, pg_catalog
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_db_bytes bigint := 0;
  v_storage_bytes bigint := 0;
  v_storage_objects bigint := 0;
  v_listings bigint := 0;
  v_events bigint := 0;
  v_users bigint := 0;
  v_buckets jsonb := '[]'::jsonb;
begin
  select exists(
    select 1 from public.admin_users
    where user_id = v_uid and is_active = true
      and role in ('super_admin','admin')
  ) into v_is_admin;

  if not v_is_admin then
    raise exception 'admin access required';
  end if;

  select pg_database_size(current_database()) into v_db_bytes;

  select
    coalesce(sum(coalesce((metadata->>'size')::bigint, 0)), 0),
    count(*)
  into v_storage_bytes, v_storage_objects
  from storage.objects;

  select count(*) into v_listings from public.listings;
  select count(*) into v_events from public.events;
  select count(*) into v_users from public.app_users;

  select coalesce(jsonb_agg(x order by (x->>'bytes')::bigint desc), '[]'::jsonb)
  into v_buckets
  from (
    select jsonb_build_object(
      'bucket', bucket_id,
      'objects', count(*),
      'bytes', coalesce(sum(coalesce((metadata->>'size')::bigint,0)),0)
    ) as x
    from storage.objects
    group by bucket_id
  ) s;

  return jsonb_build_object(
    'database_bytes', v_db_bytes,
    'storage_bytes', v_storage_bytes,
    'storage_objects', v_storage_objects,
    'listings', v_listings,
    'events', v_events,
    'users', v_users,
    'buckets', v_buckets,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.admin_platform_usage() from public, anon;
grant execute on function public.admin_platform_usage() to authenticated;
