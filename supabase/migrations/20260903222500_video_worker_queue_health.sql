create or replace view public.video_worker_queue_health as
select
  now() as observed_at,
  count(*) filter (where status='queued') as queued_jobs,
  count(*) filter (where status='processing') as processing_jobs,
  count(*) filter (where status='failed' and created_at >= now() - interval '24 hours') as failed_jobs_24h,
  count(*) filter (where status='ready' and completed_at >= now() - interval '1 hour') as completed_jobs_1h,
  count(*) filter (where status='ready' and completed_at >= now() - interval '24 hours') as completed_jobs_24h,
  extract(epoch from (now() - min(created_at) filter (where status='queued')))::bigint as oldest_queued_seconds,
  round(avg(extract(epoch from (completed_at - started_at))) filter (
    where status='ready'
      and started_at is not null
      and completed_at is not null
      and completed_at >= now() - interval '24 hours'
  )::numeric, 1) as avg_processing_seconds_24h,
  (
    count(*) filter (where status='queued') >= 20
    or coalesce(extract(epoch from (now() - min(created_at) filter (where status='queued'))), 0) >= 120
    or count(*) filter (where status='ready' and completed_at >= now() - interval '24 hours') >= 500
  ) as dedicated_worker_recommended
from public.listing_video_jobs;

revoke all on public.video_worker_queue_health from anon, authenticated;