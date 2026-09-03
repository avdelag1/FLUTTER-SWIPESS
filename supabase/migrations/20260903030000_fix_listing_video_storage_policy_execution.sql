-- Storage RLS evaluates permissive policies without guaranteed SQL short-circuiting.
-- Calling the internal paid-video helper directly from a listing-videos policy
-- caused unrelated listing-drafts uploads to fail with permission denied.
-- Keep the internal helper private and expose a narrow authenticated wrapper
-- that is safe for Storage policy evaluation.

create or replace function public._current_user_has_paid_listing_video_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public._has_paid_listing_video_access(auth.uid());
$$;

revoke execute on function public._current_user_has_paid_listing_video_access() from public, anon;
grant execute on function public._current_user_has_paid_listing_video_access() to authenticated;

-- Remove the old broad insert rule because permissive RLS policies are ORed;
-- keeping it would bypass paid Premium enforcement.
drop policy if exists "listing videos insert authenticated" on storage.objects;

drop policy if exists "listing videos insert own folder" on storage.objects;
create policy "listing videos insert own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'listing-videos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and public._current_user_has_paid_listing_video_access()
  and (
    coalesce(((public.content_quota_status()->>'can_create_listing')::boolean), false)
    or (
      (storage.foldername(name))[2] = 'listing'
      and exists (
        select 1
        from public.listings l
        where l.id::text = (storage.foldername(name))[3]
          and l.owner_id = (select auth.uid())
      )
    )
  )
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
  and public._current_user_has_paid_listing_video_access()
);
