alter table public.likes drop constraint if exists likes_target_type_check;

alter table public.likes
  add constraint likes_target_type_check
  check (
    target_type = any (
      array[
        'listing'::text,
        'profile'::text,
        'radio_station'::text,
        'event'::text
      ]
    )
  );

comment on constraint likes_target_type_check on public.likes is
  'Supported polymorphic like targets, including saved Events.';
