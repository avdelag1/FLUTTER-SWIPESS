-- A listing is owned through owner_id, not user_id. The previous soundtrack
-- trim bridge referenced a field that does not exist on public.listings, which
-- aborted the whole publish/update after media had already uploaded.
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
  if new.owner_id is null
     or new.background_music_url is null
     or btrim(new.background_music_url) = '' then
    return new;
  end if;

  select start_ms, end_ms
    into v_start, v_end
  from public.pending_listing_audio_trim
  where user_id = new.owner_id;

  if not found then
    return new;
  end if;

  v_base := split_part(new.background_music_url, '#swipess_trim=', 1);
  new.background_music_url :=
    v_base || '#swipess_trim=' || v_start::text || ',' || coalesce(v_end::text, '');
  new.background_music_trim_start_ms := v_start;
  new.background_music_trim_end_ms := v_end;

  delete from public.pending_listing_audio_trim where user_id = new.owner_id;
  return new;
end;
$$;

-- The AI listing builder has used this kind since launch. Keep restores and
-- saves valid in every environment, including a clean database setup.
alter table public.listing_drafts
  drop constraint if exists listing_drafts_kind_check;

alter table public.listing_drafts
  add constraint listing_drafts_kind_check
  check (kind in ('create', 'edit', 'ai'));
