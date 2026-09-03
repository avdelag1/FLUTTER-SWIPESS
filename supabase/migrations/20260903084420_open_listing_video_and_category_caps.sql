-- Listing videos are available to every authenticated user.
-- Listing capacity is 6 active listings per category unless a per-user override exists.

create or replace function public._has_paid_listing_video_access(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_user_id is not null;
$$;

create or replace function public.rpc_can_upload_listing_video()
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null;
$$;

drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public._has_paid_listing_video_access((select auth.uid()))
);

drop policy if exists "listing videos update own folder" on storage.objects;
create policy "listing videos update own folder"
on storage.objects for update to authenticated
using (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
)
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public._has_paid_listing_video_access((select auth.uid()))
);

create or replace function public.rpc_can_publish_listing(p_category text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_category text := lower(btrim(coalesce(p_category, '')));
  v_status jsonb;
  v_video_enabled boolean;
  v_limit integer;
  v_category_count integer;
  v_has_override boolean := false;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  v_status := public.content_quota_status();
  select exists(select 1 from public.user_content_limit_overrides o where o.user_id = v_user) into v_has_override;
  if v_has_override then
    select o.max_active_per_listing_category into v_limit from public.user_content_limit_overrides o where o.user_id = v_user;
  else
    v_limit := 6;
  end if;
  select count(*)::integer into v_category_count from public.listings x
   where x.owner_id = v_user and lower(coalesce(x.category, '')) = v_category
     and coalesce(x.is_active, true) and coalesce(x.status, 'active') = 'active';
  select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type = v_category;
  return v_status || jsonb_build_object(
    'quota_override', v_has_override, 'listing_quota_scope', 'category',
    'category', v_category, 'active_listings', v_category_count,
    'max_active_listings', v_limit,
    'listing_remaining', case when v_limit is null then null else greatest(v_limit-v_category_count,0) end,
    'can_create_listing', v_limit is null or v_category_count < v_limit,
    'video_enabled', coalesce(v_video_enabled,false),
    'can_upload_video', true, 'video_requires_paid_premium', false
  );
end;
$$;

create or replace function public.enforce_listing_content_guardrails()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_limit integer; v_count integer; v_video_enabled boolean;
  v_category text := lower(btrim(coalesce(new.category, '')));
  v_video_changed boolean := false; v_has_override boolean := false;
begin
  if public._is_active_admin(new.owner_id) then return new; end if;
  v_video_changed := new.video_url is not null and btrim(new.video_url) <> ''
    and (tg_op = 'INSERT' or old.video_url is distinct from new.video_url);
  if v_video_changed then
    select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type = v_category;
    if coalesce(v_video_enabled,false) = false then raise exception 'Video is not enabled for % listings', coalesce(new.category,'this category'); end if;
  end if;
  if coalesce(new.is_active,true) and coalesce(new.status,'active') = 'active' then
    if tg_op = 'UPDATE' and coalesce(old.is_active,true) and coalesce(old.status,'active') = 'active'
       and lower(btrim(coalesce(old.category,''))) = v_category then return new; end if;
    select exists(select 1 from public.user_content_limit_overrides o where o.user_id = new.owner_id) into v_has_override;
    if v_has_override then
      select o.max_active_per_listing_category into v_limit from public.user_content_limit_overrides o where o.user_id = new.owner_id;
    else
      v_limit := 6;
    end if;
    if v_limit is not null then
      select count(*)::integer into v_count from public.listings x
       where x.owner_id = new.owner_id and lower(btrim(coalesce(x.category,''))) = v_category
         and coalesce(x.is_active,true) and coalesce(x.status,'active') = 'active'
         and (tg_op <> 'UPDATE' or x.id <> new.id);
      if v_count >= v_limit then raise exception 'Active % listing limit reached (% listings)', v_category, v_limit; end if;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function public._has_paid_listing_video_access(uuid) from public, anon, authenticated;
revoke execute on function public.enforce_listing_content_guardrails() from public, anon, authenticated;
revoke execute on function public.rpc_can_upload_listing_video() from public, anon;
grant execute on function public.rpc_can_upload_listing_video() to authenticated;
revoke execute on function public.rpc_can_publish_listing(text) from public, anon;
grant execute on function public.rpc_can_publish_listing(text) to authenticated;
