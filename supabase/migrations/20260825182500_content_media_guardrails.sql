-- SWIPESS content/media guardrails

alter table public.listings drop constraint if exists listings_category_check;
alter table public.listings
  add constraint listings_category_check
  check (category = any (array['property'::text,'motorcycle'::text,'bicycle'::text,'worker'::text,'yacht'::text]));

create table if not exists public.account_content_limits (
  tier text primary key,
  max_active_listings integer null check (max_active_listings is null or max_active_listings >= 0),
  max_active_events integer null check (max_active_events is null or max_active_events >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid null references auth.users(id)
);
alter table public.account_content_limits enable row level security;
insert into public.account_content_limits (tier, max_active_listings, max_active_events)
values ('free',5,3),('basic',25,20),('premium',100,50),('premium_plus',250,100),('unlimited',null,null),('pay_per_use',5,3)
on conflict (tier) do nothing;

create table if not exists public.platform_media_rules (
  content_type text primary key,
  video_enabled boolean not null default false,
  max_videos_per_item integer not null default 0 check (max_videos_per_item >= 0),
  max_duration_seconds integer null check (max_duration_seconds is null or max_duration_seconds > 0),
  max_file_size_bytes bigint null check (max_file_size_bytes is null or max_file_size_bytes > 0),
  autoplay_preview boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid null references auth.users(id)
);
alter table public.platform_media_rules enable row level security;
insert into public.platform_media_rules(content_type,video_enabled,max_videos_per_item,max_duration_seconds,max_file_size_bytes,autoplay_preview)
values
 ('property',true,1,30,52428800,true),('yacht',true,1,30,52428800,true),('event',true,1,30,52428800,true),
 ('motorcycle',false,0,null,null,false),('bicycle',false,0,null,null,false),('worker',false,0,null,null,false),('profile',false,0,null,null,false)
on conflict (content_type) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('listing-videos','listing-videos',true,52428800,array['video/mp4','video/quicktime','video/webm']::text[])
on conflict (id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder" on storage.objects for insert to authenticated
with check (bucket_id='listing-videos' and (storage.foldername(name))[1]=(select auth.uid()::text));
drop policy if exists "listing videos update own folder" on storage.objects;
create policy "listing videos update own folder" on storage.objects for update to authenticated
using (bucket_id='listing-videos' and (storage.foldername(name))[1]=(select auth.uid()::text))
with check (bucket_id='listing-videos' and (storage.foldername(name))[1]=(select auth.uid()::text));
drop policy if exists "listing videos delete own folder" on storage.objects;
create policy "listing videos delete own folder" on storage.objects for delete to authenticated
using (bucket_id='listing-videos' and (storage.foldername(name))[1]=(select auth.uid()::text));

create or replace function public._is_active_admin(p_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_users au where au.user_id=p_user_id and au.is_active=true);
$$;
create or replace function public._is_super_admin(p_user_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_users au where au.user_id=p_user_id and au.is_active=true and au.role='super_admin');
$$;
create or replace function public._effective_content_tier(p_user_id uuid) returns text language plpgsql stable security definer set search_path='' as $$
declare v_tier text;
begin
 select sp.tier into v_tier from public.user_subscriptions us join public.subscription_packages sp on sp.id=us.package_id
 where us.user_id=p_user_id and us.is_active=true and us.payment_status='paid' and (us.end_date is null or us.end_date>now()) and sp.is_active=true
 and sp.tier in ('free','basic','premium','premium_plus','unlimited','pay_per_use')
 order by case sp.tier when 'unlimited' then 6 when 'premium_plus' then 5 when 'premium' then 4 when 'basic' then 3 when 'pay_per_use' then 2 else 1 end desc,us.created_at desc limit 1;
 if v_tier is null then select lower(p.package) into v_tier from public.profiles p where p.id=p_user_id and lower(coalesce(p.package,'')) in ('free','basic','premium','premium_plus','unlimited','pay_per_use') limit 1; end if;
 return coalesce(v_tier,'free');
end; $$;

create or replace function public.content_quota_status() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_tier text; v_listing_limit integer; v_event_limit integer; v_listing_count integer; v_event_count integer;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 v_tier:=public._effective_content_tier(v_user);
 select l.max_active_listings,l.max_active_events into v_listing_limit,v_event_limit from public.account_content_limits l where l.tier=v_tier;
 select count(*)::integer into v_listing_count from public.listings x where x.owner_id=v_user and coalesce(x.is_active,true)=true and coalesce(x.status,'active')='active';
 select count(*)::integer into v_event_count from public.business_promo_submissions e where e.user_id=v_user and e.status in ('pending','approved') and (e.published_event_id is not null or e.event_type is not null or e.title is not null);
 return jsonb_build_object('tier',v_tier,'active_listings',v_listing_count,'max_active_listings',v_listing_limit,'listing_remaining',case when v_listing_limit is null then null else greatest(v_listing_limit-v_listing_count,0) end,'can_create_listing',v_listing_limit is null or v_listing_count<v_listing_limit,'active_or_pending_events',v_event_count,'max_active_events',v_event_limit,'event_remaining',case when v_event_limit is null then null else greatest(v_event_limit-v_event_count,0) end,'can_create_event',v_event_limit is null or v_event_count<v_event_limit);
end; $$;

create or replace function public.rpc_can_publish_listing(p_category text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_status jsonb; v_video_enabled boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 v_status:=public.content_quota_status();
 select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type=lower(coalesce(p_category,''));
 return v_status||jsonb_build_object('category',lower(coalesce(p_category,'')),'video_enabled',coalesce(v_video_enabled,false));
end; $$;

create or replace function public.enforce_listing_content_guardrails() returns trigger language plpgsql security definer set search_path='' as $$
declare v_tier text; v_limit integer; v_count integer; v_video_enabled boolean;
begin
 if public._is_active_admin(new.owner_id) then return new; end if;
 if new.video_url is not null and btrim(new.video_url)<>'' then
  select mr.video_enabled into v_video_enabled from public.platform_media_rules mr where mr.content_type=lower(coalesce(new.category,''));
  if coalesce(v_video_enabled,false)=false then raise exception 'Video is not enabled for % listings',coalesce(new.category,'this category'); end if;
 end if;
 if coalesce(new.is_active,true)=true and coalesce(new.status,'active')='active' then
  if tg_op='UPDATE' and coalesce(old.is_active,true)=true and coalesce(old.status,'active')='active' then return new; end if;
  v_tier:=public._effective_content_tier(new.owner_id); select l.max_active_listings into v_limit from public.account_content_limits l where l.tier=v_tier;
  if v_limit is not null then
   select count(*)::integer into v_count from public.listings x where x.owner_id=new.owner_id and coalesce(x.is_active,true)=true and coalesce(x.status,'active')='active' and (tg_op<>'UPDATE' or x.id<>new.id);
   if v_count>=v_limit then raise exception 'Active listing limit reached for % tier (% listings)',v_tier,v_limit; end if;
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists trg_listing_content_guardrails on public.listings;
create trigger trg_listing_content_guardrails before insert or update of status,is_active,video_url,category on public.listings for each row execute function public.enforce_listing_content_guardrails();

create or replace function public.enforce_event_content_guardrails() returns trigger language plpgsql security definer set search_path='' as $$
declare v_tier text; v_limit integer; v_count integer;
begin
 if new.user_id is null or public._is_active_admin(new.user_id) then return new; end if;
 if new.video_url is not null and btrim(new.video_url)<>'' and not exists(select 1 from public.platform_media_rules mr where mr.content_type='event' and mr.video_enabled=true) then raise exception 'Event video uploads are currently disabled'; end if;
 if coalesce(new.status,'pending') in ('pending','approved') then
  if tg_op='UPDATE' and coalesce(old.status,'pending') in ('pending','approved') then return new; end if;
  v_tier:=public._effective_content_tier(new.user_id); select l.max_active_events into v_limit from public.account_content_limits l where l.tier=v_tier;
  if v_limit is not null then
   select count(*)::integer into v_count from public.business_promo_submissions e where e.user_id=new.user_id and e.status in ('pending','approved') and (tg_op<>'UPDATE' or e.id<>new.id);
   if v_count>=v_limit then raise exception 'Active/pending event limit reached for % tier (% events)',v_tier,v_limit; end if;
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists trg_event_content_guardrails on public.business_promo_submissions;
create trigger trg_event_content_guardrails before insert or update of status,video_url on public.business_promo_submissions for each row execute function public.enforce_event_content_guardrails();

create or replace function public.admin_content_guardrails() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public._is_active_admin(auth.uid()) then raise exception 'Admin access required'; end if;
 return jsonb_build_object('limits',coalesce((select jsonb_agg(jsonb_build_object('tier',l.tier,'max_active_listings',l.max_active_listings,'max_active_events',l.max_active_events,'unlimited_listings',l.max_active_listings is null,'unlimited_events',l.max_active_events is null) order by case l.tier when 'free' then 1 when 'basic' then 2 when 'premium' then 3 when 'premium_plus' then 4 when 'unlimited' then 5 else 6 end) from public.account_content_limits l),'[]'::jsonb),'media_rules',coalesce((select jsonb_agg(jsonb_build_object('content_type',m.content_type,'video_enabled',m.video_enabled,'max_videos_per_item',m.max_videos_per_item,'max_duration_seconds',m.max_duration_seconds,'max_file_size_bytes',m.max_file_size_bytes,'autoplay_preview',m.autoplay_preview) order by m.content_type) from public.platform_media_rules m),'[]'::jsonb));
end; $$;

create or replace function public.admin_update_content_limit(p_tier text,p_max_active_listings integer,p_max_active_events integer) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public._is_super_admin(auth.uid()) then raise exception 'Super admin access required'; end if;
 if p_max_active_listings is not null and p_max_active_listings<0 then raise exception 'Invalid listing limit'; end if; if p_max_active_events is not null and p_max_active_events<0 then raise exception 'Invalid event limit'; end if;
 insert into public.account_content_limits(tier,max_active_listings,max_active_events,updated_at,updated_by) values(lower(p_tier),p_max_active_listings,p_max_active_events,now(),auth.uid())
 on conflict(tier) do update set max_active_listings=excluded.max_active_listings,max_active_events=excluded.max_active_events,updated_at=now(),updated_by=auth.uid();
end; $$;
create or replace function public.admin_update_media_rule(p_content_type text,p_video_enabled boolean,p_max_duration_seconds integer,p_max_file_size_bytes bigint,p_autoplay_preview boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public._is_super_admin(auth.uid()) then raise exception 'Super admin access required'; end if;
 if p_video_enabled and (p_max_duration_seconds is null or p_max_duration_seconds<=0) then raise exception 'Video duration must be positive'; end if; if p_video_enabled and (p_max_file_size_bytes is null or p_max_file_size_bytes<=0) then raise exception 'Video file size must be positive'; end if;
 insert into public.platform_media_rules(content_type,video_enabled,max_videos_per_item,max_duration_seconds,max_file_size_bytes,autoplay_preview,updated_at,updated_by)
 values(lower(p_content_type),p_video_enabled,case when p_video_enabled then 1 else 0 end,p_max_duration_seconds,p_max_file_size_bytes,p_autoplay_preview,now(),auth.uid())
 on conflict(content_type) do update set video_enabled=excluded.video_enabled,max_videos_per_item=excluded.max_videos_per_item,max_duration_seconds=excluded.max_duration_seconds,max_file_size_bytes=excluded.max_file_size_bytes,autoplay_preview=excluded.autoplay_preview,updated_at=now(),updated_by=auth.uid();
end; $$;

revoke execute on function public._is_active_admin(uuid) from public,anon,authenticated;
revoke execute on function public._is_super_admin(uuid) from public,anon,authenticated;
revoke execute on function public._effective_content_tier(uuid) from public,anon,authenticated;
revoke execute on function public.enforce_listing_content_guardrails() from public,anon,authenticated;
revoke execute on function public.enforce_event_content_guardrails() from public,anon,authenticated;
revoke execute on function public.content_quota_status() from public,anon; grant execute on function public.content_quota_status() to authenticated;
revoke execute on function public.rpc_can_publish_listing(text) from public,anon; grant execute on function public.rpc_can_publish_listing(text) to authenticated;
revoke execute on function public.admin_content_guardrails() from public,anon; grant execute on function public.admin_content_guardrails() to authenticated;
revoke execute on function public.admin_update_content_limit(text,integer,integer) from public,anon; grant execute on function public.admin_update_content_limit(text,integer,integer) to authenticated;
revoke execute on function public.admin_update_media_rule(text,boolean,integer,bigint,boolean) from public,anon; grant execute on function public.admin_update_media_rule(text,boolean,integer,bigint,boolean) to authenticated;
