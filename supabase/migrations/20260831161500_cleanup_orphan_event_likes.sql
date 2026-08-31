-- Remove Saved Event rows whose event no longer exists. These stale likes can
-- survive event deletion because the generic likes table has no event FK.
delete from public.likes l
where l.target_type = 'event'
  and not exists (
    select 1
    from public.events e
    where e.id = l.target_id
  );
