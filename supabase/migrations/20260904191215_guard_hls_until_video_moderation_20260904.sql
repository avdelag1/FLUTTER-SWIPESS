create or replace function private.guard_listing_video_promotion()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if coalesce(new.video_moderation_status, old.video_moderation_status, 'none') <> 'approved' then
    if new.video_url is distinct from old.video_url
       and new.video_url is not null
       and position('/processed/' in new.video_url) > 0 then
      return null;
    end if;

    if new.video_hls_url is distinct from old.video_hls_url
       and new.video_hls_url is not null
       and btrim(new.video_hls_url) <> '' then
      return null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists aaa_listings_guard_video_promotion on public.listings;
create trigger aaa_listings_guard_video_promotion
before update of video_url, video_hls_url on public.listings
for each row execute function private.guard_listing_video_promotion();
