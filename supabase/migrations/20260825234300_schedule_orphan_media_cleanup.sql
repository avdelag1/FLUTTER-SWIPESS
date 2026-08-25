create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

create table if not exists public.internal_job_secrets (
  job_name text primary key,
  secret text not null,
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);
alter table public.internal_job_secrets enable row level security;
revoke all on public.internal_job_secrets from public, anon, authenticated;
insert into public.internal_job_secrets(job_name, secret)
values ('cleanup-orphan-media', encode(gen_random_bytes(32), 'hex'))
on conflict (job_name) do nothing;

create table if not exists public.infrastructure_job_runs (
  id bigint generated always as identity primary key,
  job_name text not null,
  status text not null,
  items_processed integer not null default 0,
  items_removed integer not null default 0,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.infrastructure_job_runs enable row level security;
revoke all on public.infrastructure_job_runs from public, anon, authenticated;

grant select on public.internal_job_secrets to service_role;
grant insert, select on public.infrastructure_job_runs to service_role;

create or replace function public.internal_orphan_media_candidates(
  p_older_than_hours integer default 24,
  p_limit integer default 500
)
returns table(bucket text, path text)
language sql
security definer
set search_path = public, pg_temp
as $$
  with candidate_videos as (
    select o.bucket_id::text as bucket, o.name::text as path, o.created_at
    from storage.objects o
    where o.bucket_id = 'listing-videos'
      and o.created_at < now() - make_interval(hours => greatest(p_older_than_hours, 1))
      and not exists (
        select 1 from public.listings l
        where l.video_url is not null and l.video_url like '%' || o.name
      )
  ), candidate_images as (
    select o.bucket_id::text as bucket, o.name::text as path, o.created_at
    from storage.objects o
    where o.bucket_id = 'listing-images'
      and o.created_at < now() - make_interval(hours => greatest(p_older_than_hours, 1))
      and not exists (
        select 1 from public.listings l
        where exists (
          select 1
          from unnest(coalesce(l.images, array[]::text[])) u(url)
          where u.url like '%' || o.name
        )
      )
  )
  select bucket, path
  from (
    select * from candidate_videos
    union all
    select * from candidate_images
  ) q
  order by created_at asc
  limit least(greatest(p_limit, 1), 1000);
$$;
revoke execute on function public.internal_orphan_media_candidates(integer, integer) from public, anon, authenticated;
grant execute on function public.internal_orphan_media_candidates(integer, integer) to service_role;

create or replace function public.admin_infrastructure_job_status()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_last public.infrastructure_job_runs%rowtype;
  v_candidates bigint := 0;
begin
  select exists(
    select 1 from public.admin_users au
    where au.user_id = v_uid and coalesce(au.is_active, true) = true
  ) into v_is_admin;
  if not v_is_admin then raise exception 'admin access required'; end if;

  select * into v_last
  from public.infrastructure_job_runs
  where job_name='cleanup-orphan-media'
  order by created_at desc
  limit 1;

  select count(*) into v_candidates
  from public.internal_orphan_media_candidates(24,1000);

  return jsonb_build_object(
    'job_name','cleanup-orphan-media',
    'schedule','daily',
    'orphan_candidates',v_candidates,
    'last_run', case when v_last.id is null then null else jsonb_build_object(
      'status',v_last.status,
      'items_processed',v_last.items_processed,
      'items_removed',v_last.items_removed,
      'created_at',v_last.created_at,
      'details',v_last.details
    ) end
  );
end;
$$;
revoke execute on function public.admin_infrastructure_job_status() from public, anon;
grant execute on function public.admin_infrastructure_job_status() to authenticated;

do $$
declare existing_id bigint;
begin
  select jobid into existing_id from cron.job where jobname='cleanup-orphan-media-daily' limit 1;
  if existing_id is not null then perform cron.unschedule(existing_id); end if;
end $$;

select cron.schedule(
  'cleanup-orphan-media-daily',
  '20 4 * * *',
  $cron$
  select net.http_post(
    url := 'https://vplgtcguxujxwrgguxqq.supabase.co/functions/v1/cleanup-orphan-media',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-job-secret',(select secret from public.internal_job_secrets where job_name='cleanup-orphan-media')
    ),
    body := '{}'::jsonb
  );
  $cron$
);
