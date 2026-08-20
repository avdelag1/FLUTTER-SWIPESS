create or replace function public.finalize_event_promo_purchase(
  p_user_id uuid,
  p_submission_id uuid,
  p_product_id text,
  p_transaction_id text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  s public.business_promo_submissions%rowtype;
  v_event_id uuid;
  v_package text;
  v_event_date timestamptz;
begin
  if p_user_id is null or p_submission_id is null or coalesce(trim(p_product_id), '') = '' or coalesce(trim(p_transaction_id), '') = '' then
    raise exception 'Missing event promotion purchase context';
  end if;

  v_package := case p_product_id
    when 'Swipess.promo.event.week.v3' then 'starter'
    when 'Swipess.promo.event.month.v3' then 'growth'
    when 'Swipess.promo.event.quarter.v3' then 'premium'
    else null
  end;
  if v_package is null then
    raise exception 'Unsupported event promotion product';
  end if;

  select * into s
  from public.business_promo_submissions
  where id = p_submission_id
  for update;

  if not found then
    raise exception 'Promotion submission not found';
  end if;
  if s.user_id is distinct from p_user_id then
    raise exception 'Promotion submission does not belong to this user';
  end if;

  if s.is_review_demo then
    if s.status <> 'approved' then
      raise exception 'Review demo must be approved before payment';
    end if;

    update public.business_promo_submissions
    set package = p_product_id,
        approved_at = coalesce(approved_at, now()),
        paid_at = now(),
        payment_product_id = p_product_id,
        payment_transaction_id = p_transaction_id,
        published_event_id = null,
        updated_at = now()
    where id = p_submission_id;

    perform public.create_notification_for_user(
      p_user_id,
      'system_announcement',
      'App Review purchase verified',
      'The native App Store event-promotion purchase was verified successfully. The review demo remains ready for another sandbox test when reopened.',
      null,
      jsonb_build_object('submission_id', p_submission_id, 'product_id', p_product_id, 'review_demo', true)
    );

    return null;
  end if;

  if s.status in ('paid', 'live') then
    if s.payment_transaction_id = p_transaction_id and s.payment_product_id = p_product_id then
      return s.published_event_id;
    end if;
    raise exception 'Promotion submission is already paid';
  end if;

  if s.status <> 'approved' then
    raise exception 'Promotion must be approved before payment';
  end if;

  begin
    if nullif(trim(s.event_date), '') is not null then
      v_event_date := s.event_date::timestamptz;
    end if;
  exception when others then
    v_event_date := null;
  end;

  insert into public.events (
    title,
    description,
    category,
    image_url,
    video_url,
    event_date,
    location,
    organizer_name,
    organizer_whatsapp,
    is_approved,
    is_published,
    is_promo,
    promo_status,
    selected_promo_package
  ) values (
    coalesce(nullif(trim(s.title), ''), nullif(trim(s.business_name), ''), 'Promoted Event'),
    s.description,
    coalesce(nullif(trim(s.event_type), ''), nullif(trim(s.promo_type), ''), 'event'),
    s.image_url,
    s.video_url,
    v_event_date,
    s.location,
    coalesce(nullif(trim(s.contact_name), ''), nullif(trim(s.owner_name), '')),
    coalesce(nullif(trim(s.contact_phone), ''), nullif(trim(s.whatsapp), '')),
    true,
    true,
    true,
    'active',
    v_package
  ) returning id into v_event_id;

  update public.business_promo_submissions
  set status = 'live',
      package = p_product_id,
      approved_at = coalesce(approved_at, now()),
      paid_at = now(),
      payment_product_id = p_product_id,
      payment_transaction_id = p_transaction_id,
      published_event_id = v_event_id,
      updated_at = now()
  where id = p_submission_id;

  perform public.create_notification_for_user(
    p_user_id,
    'system_announcement',
    'Your event is live! 🎉',
    format('“%s” is approved, paid, and now live in Events.', coalesce(s.title, 'Your event')),
    null,
    jsonb_build_object('submission_id', p_submission_id, 'event_id', v_event_id, 'product_id', p_product_id)
  );

  return v_event_id;
end;
$$;

revoke all on function public.finalize_event_promo_purchase(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.finalize_event_promo_purchase(uuid, uuid, text, text) to service_role;
