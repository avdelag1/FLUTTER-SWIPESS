create schema if not exists private;

alter table public.listings
  add column if not exists video_original_url text,
  add column if not exists video_playback_url text,
  add column if not exists video_poster_url text,
  add column if not exists video_processing_status text not null default 'none',
  add column if not exists video_processing_error text,
  add column if not exists video_processed_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'listings_video_processing_status_check'
      and conrelid = 'public.listings'::regclass
  ) then
    alter table public.listings
      add constraint listings_video_processing_status_check
      check (video_processing_status in ('none','queued','processing','ready','failed'));
  end if;
end $$;

create table if not exists public.listing_video_jobs (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  owner_id uuid not null,
  source_url text not null,
  worker_token text not null,
  status text not null default 'queued'
    check (status in ('queued','processing','ready','failed','superseded')),
  attempt_count integer not null default 0,
  output_video_path text,
  output_poster_path text,
  playback_url text,
  poster_url text,
  source_size_bytes bigint,
  output_size_bytes bigint,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

create index if not exists listing_video_jobs_listing_idx
  on public.listing_video_jobs(listing_id, created_at desc);
create index if not exists listing_video_jobs_status_idx
  on public.listing_video_jobs(status, created_at);

alter table public.listing_video_jobs enable row level security;
revoke all on table public.listing_video_jobs from anon, authenticated;

drop trigger if exists listing_video_jobs_touch_updated_at on public.listing_video_jobs;
create or replace function private.touch_listing_video_job_updated_at()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger listing_video_jobs_touch_updated_at
before update on public.listing_video_jobs
for each row execute function private.touch_listing_video_job_updated_at();

insert into public.internal_job_secrets(job_name, secret)
select 'listing-video-pipeline', encode(gen_random_bytes(32), 'hex')
where not exists (
  select 1 from public.internal_job_secrets where job_name = 'listing-video-pipeline'
);

create or replace function private.prepare_listing_video_processing()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if tg_op = 'INSERT' or new.video_url is distinct from old.video_url then
    if new.video_url is null or btrim(new.video_url) = '' then
      new.video_original_url := null;
      new.video_playback_url := null;
      new.video_poster_url := null;
      new.video_processing_status := 'none';
      new.video_processing_error := null;
      new.video_processed_at := null;
    elsif position('/processed/' in new.video_url) > 0 then
      -- The trusted worker is promoting its completed rendition into video_url.
      -- Preserve video_original_url and the ready metadata written in the same update.
      null;
    else
      new.video_original_url := new.video_url;
      new.video_playback_url := null;
      new.video_poster_url := null;
      new.video_processing_status := 'queued';
      new.video_processing_error := null;
      new.video_processed_at := null;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.queue_listing_video_processing()
returns trigger
language plpgsql
security definer
set search_path = public, private, net, pg_temp
as $$
declare
  v_secret text;
begin
  if (tg_op = 'INSERT' or new.video_url is distinct from old.video_url)
     and new.video_url is not null
     and btrim(new.video_url) <> ''
     and position('/processed/' in new.video_url) = 0 then
    select secret into v_secret
    from public.internal_job_secrets
    where job_name = 'listing-video-pipeline';

    if v_secret is not null then
      perform net.http_post(
        url := 'https://vplgtcguxujxwrgguxqq.supabase.co/functions/v1/video-pipeline',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-job-secret', v_secret
        ),
        body := jsonb_build_object(
          'action', 'start_internal',
          'listing_id', new.id::text
        ),
        timeout_milliseconds := 5000
      );
    end if;
  end if;
  return null;
end;
$$;

revoke all on function private.prepare_listing_video_processing() from public;
revoke all on function private.queue_listing_video_processing() from public;
revoke all on function private.touch_listing_video_job_updated_at() from public;

drop trigger if exists listings_prepare_video_processing on public.listings;
create trigger listings_prepare_video_processing
before insert or update of video_url on public.listings
for each row execute function private.prepare_listing_video_processing();

drop trigger if exists listings_queue_video_processing on public.listings;
create trigger listings_queue_video_processing
after insert or update of video_url on public.listings
for each row execute function private.queue_listing_video_processing();
