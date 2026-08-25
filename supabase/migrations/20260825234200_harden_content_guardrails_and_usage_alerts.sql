create table if not exists public.infrastructure_alert_thresholds (
  singleton boolean primary key default true check (singleton),
  database_warn_bytes bigint not null default 1073741824,
  database_critical_bytes bigint not null default 5368709120,
  storage_warn_bytes bigint not null default 53687091200,
  storage_critical_bytes bigint not null default 96636764160,
  storage_objects_warn bigint not null default 100000,
  orphan_media_warn bigint not null default 25,
  updated_at timestamptz not null default now()
);

insert into public.infrastructure_alert_thresholds(singleton)
values (true)
on conflict (singleton) do nothing;

alter table public.infrastructure_alert_thresholds enable row level security;
revoke all on public.infrastructure_alert_thresholds from anon, authenticated;

create or replace function public.admin_infrastructure_alerts()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_db bigint := 0;
  v_storage bigint := 0;
  v_objects bigint := 0;
  v_orphans bigint := 0;
  v_t public.infrastructure_alert_thresholds%rowtype;
  v_alerts jsonb := '[]'::jsonb;
begin
  select exists(
    select 1 from public.admin_users au
    where au.user_id = v_uid and coalesce(au.is_active, true) = true
  ) into v_is_admin;
  if not v_is_admin then raise exception 'admin access required'; end if;

  select pg_database_size(current_database()) into v_db;
  select coalesce(sum((metadata->>'size')::bigint),0), count(*) into v_storage, v_objects from storage.objects;
  select count(*) into v_orphans
  from storage.objects o
  where o.bucket_id = 'listing-videos'
    and o.created_at < now() - interval '6 hours'
    and not exists (
      select 1 from public.listings l
      where l.video_url is not null and l.video_url like '%' || o.name
    );

  select * into v_t from public.infrastructure_alert_thresholds where singleton = true;

  if v_db >= v_t.database_critical_bytes then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','critical','key','database','message','Database usage crossed the critical operational threshold.','value',v_db,'threshold',v_t.database_critical_bytes));
  elsif v_db >= v_t.database_warn_bytes then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','warning','key','database','message','Database usage crossed the warning operational threshold.','value',v_db,'threshold',v_t.database_warn_bytes));
  end if;

  if v_storage >= v_t.storage_critical_bytes then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','critical','key','storage','message','File storage crossed the critical operational threshold.','value',v_storage,'threshold',v_t.storage_critical_bytes));
  elsif v_storage >= v_t.storage_warn_bytes then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','warning','key','storage','message','File storage crossed the warning operational threshold.','value',v_storage,'threshold',v_t.storage_warn_bytes));
  end if;

  if v_objects >= v_t.storage_objects_warn then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','warning','key','objects','message','Stored file count crossed the operational threshold.','value',v_objects,'threshold',v_t.storage_objects_warn));
  end if;

  if v_orphans >= v_t.orphan_media_warn then
    v_alerts := v_alerts || jsonb_build_array(jsonb_build_object('level','warning','key','orphans','message','Unreferenced listing videos need cleanup.','value',v_orphans,'threshold',v_t.orphan_media_warn));
  end if;

  return jsonb_build_object(
    'status', case when jsonb_array_length(v_alerts)=0 then 'healthy' else 'attention' end,
    'alerts', v_alerts,
    'orphan_listing_videos', v_orphans,
    'database_bytes', v_db,
    'storage_bytes', v_storage,
    'storage_objects', v_objects,
    'checked_at', now()
  );
end;
$$;

create or replace function public.admin_update_infrastructure_thresholds(
  p_database_warn_bytes bigint,
  p_database_critical_bytes bigint,
  p_storage_warn_bytes bigint,
  p_storage_critical_bytes bigint,
  p_storage_objects_warn bigint,
  p_orphan_media_warn bigint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_super boolean := false;
begin
  select exists(
    select 1 from public.admin_users au
    where au.user_id = v_uid and coalesce(au.is_active, true) = true and au.role = 'super_admin'
  ) into v_super;
  if not v_super then raise exception 'super admin access required'; end if;
  if p_database_warn_bytes < 0 or p_database_critical_bytes <= p_database_warn_bytes
     or p_storage_warn_bytes < 0 or p_storage_critical_bytes <= p_storage_warn_bytes
     or p_storage_objects_warn < 1 or p_orphan_media_warn < 1 then
    raise exception 'invalid infrastructure thresholds';
  end if;
  update public.infrastructure_alert_thresholds set
    database_warn_bytes = p_database_warn_bytes,
    database_critical_bytes = p_database_critical_bytes,
    storage_warn_bytes = p_storage_warn_bytes,
    storage_critical_bytes = p_storage_critical_bytes,
    storage_objects_warn = p_storage_objects_warn,
    orphan_media_warn = p_orphan_media_warn,
    updated_at = now()
  where singleton = true;
end;
$$;

revoke execute on function public.admin_platform_usage() from public, anon;
revoke execute on function public.admin_content_guardrails() from public, anon;
revoke execute on function public.admin_update_content_limit(text, integer, integer) from public, anon;
revoke execute on function public.admin_update_media_rule(text, boolean, integer, bigint, boolean) from public, anon;
revoke execute on function public.content_quota_status() from public, anon;
revoke execute on function public.rpc_can_publish_listing(text) from public, anon;
revoke execute on function public.admin_infrastructure_alerts() from public, anon;
revoke execute on function public.admin_update_infrastructure_thresholds(bigint,bigint,bigint,bigint,bigint,bigint) from public, anon;

grant execute on function public.admin_platform_usage() to authenticated;
grant execute on function public.admin_content_guardrails() to authenticated;
grant execute on function public.admin_update_content_limit(text, integer, integer) to authenticated;
grant execute on function public.admin_update_media_rule(text, boolean, integer, bigint, boolean) to authenticated;
grant execute on function public.content_quota_status() to authenticated;
grant execute on function public.rpc_can_publish_listing(text) to authenticated;
grant execute on function public.admin_infrastructure_alerts() to authenticated;
grant execute on function public.admin_update_infrastructure_thresholds(bigint,bigint,bigint,bigint,bigint,bigint) to authenticated;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.prosecdef
      and (p.proname like 'admin_%'
           or p.proname in ('block_user','unblock_user','manage_user_verification','delete_user_account'))
  loop
    execute format('revoke execute on function %s from public, anon', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;
