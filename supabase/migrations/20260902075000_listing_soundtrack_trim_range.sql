alter table public.listings
  add column if not exists background_music_trim_start_ms integer not null default 0,
  add column if not exists background_music_trim_end_ms integer;

alter table public.listings
  drop constraint if exists listings_background_music_trim_range_check;

alter table public.listings
  add constraint listings_background_music_trim_range_check
  check (
    background_music_trim_start_ms >= 0
    and (
      background_music_trim_end_ms is null
      or background_music_trim_end_ms > background_music_trim_start_ms
    )
  );
