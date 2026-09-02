create table if not exists public.pending_listing_audio_trim (
  user_id uuid primary key references auth.users(id) on delete cascade,
  start_ms integer not null default 0 check (start_ms >= 0),
  end_ms integer,
  updated_at timestamptz not null default now(),
  check (end_ms is null or end_ms > start_ms)
);

alter table public.pending_listing_audio_trim enable row level security;

drop policy if exists "pending trim own select" on public.pending_listing_audio_trim;
create policy "pending trim own select"
on public.pending_listing_audio_trim for select
using (user_id = auth.uid());

drop policy if exists "pending trim own insert" on public.pending_listing_audio_trim;
create policy "pending trim own insert"
on public.pending_listing_audio_trim for insert
with check (user_id = auth.uid());

drop policy if exists "pending trim own update" on public.pending_listing_audio_trim;
create policy "pending trim own update"
on public.pending_listing_audio_trim for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "pending trim own delete" on public.pending_listing_audio_trim;
create policy "pending trim own delete"
on public.pending_listing_audio_trim for delete
using (user_id = auth.uid());

create or replace function public.apply_pending_listing_audio_trim()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start integer;
  v_end integer;
  v_base text;
begin
  if new.user_id is null or new.background_music_url is null or btrim(new.background_music_url) = '' then
    return new;
  end if;

  select start_ms, end_ms
    into v_start, v_end
  from public.pending_listing_audio_trim
  where user_id = new.user_id;

  if not found then
    return new;
  end if;

  v_base := split_part(new.background_music_url, '#swipess_trim=', 1);
  new.background_music_url := v_base || '#swipess_trim=' || v_start::text || ',' || coalesce(v_end::text, '');
  new.background_music_trim_start_ms := v_start;
  new.background_music_trim_end_ms := v_end;

  delete from public.pending_listing_audio_trim where user_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_apply_pending_listing_audio_trim on public.listings;
create trigger trg_apply_pending_listing_audio_trim
before insert or update of background_music_url on public.listings
for each row execute function public.apply_pending_listing_audio_trim();
