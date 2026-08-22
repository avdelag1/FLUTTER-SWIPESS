-- Complete the free-interest loop for both supply listings and canonical
-- I Need/Seeker request listings.
--
-- right swipe = free interest -> owner/requester receives notification
-- owner/requester accepts -> existing rpc_accept_listing_interest creates
-- a mutual match + free chat.

CREATE OR REPLACE FUNCTION public.notify_listing_interest()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_owner_id uuid;
  v_title text;
  v_is_need boolean := false;
  v_actor_name text;
BEGIN
  -- Only notify on a transition INTO right/Interested. Replaying the same
  -- decision must not spam the listing owner.
  IF NEW.target_type <> 'listing' OR NEW.direction <> 'right' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.direction = 'right' THEN
    RETURN NEW;
  END IF;

  SELECT
    l.owner_id,
    COALESCE(NULLIF(trim(l.title), ''), 'your listing'),
    (l.listing_type = 'request' AND l.mode = 'seek')
  INTO v_owner_id, v_title, v_is_need
  FROM public.listings l
  WHERE l.id = NEW.target_id
    AND COALESCE(l.is_active, true) = true;

  IF v_owner_id IS NULL OR v_owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
    NULLIF(trim(cp.name), ''),
    NULLIF(trim(p.full_name), ''),
    'Someone'
  )
  INTO v_actor_name
  FROM (SELECT NEW.user_id AS id) x
  LEFT JOIN public.client_profiles cp ON cp.user_id = x.id
  LEFT JOIN public.profiles p ON p.id = x.id;

  v_actor_name := COALESCE(v_actor_name, 'Someone');

  INSERT INTO public.notifications(
    user_id,
    notification_type,
    title,
    message,
    link_url,
    related_user_id,
    related_property_id,
    metadata,
    is_read
  ) VALUES (
    v_owner_id,
    'new_like',
    CASE WHEN v_is_need THEN 'Someone can help' ELSE 'New interest' END,
    CASE
      WHEN v_is_need THEN v_actor_name || ' is interested in your request: ' || left(v_title, 90)
      ELSE v_actor_name || ' is interested in ' || left(v_title, 100)
    END,
    '/interest/' || NEW.target_id::text || '/' || NEW.user_id::text,
    NEW.user_id,
    NEW.target_id,
    jsonb_build_object(
      'listing_id', NEW.target_id,
      'liker_id', NEW.user_id,
      'is_need', v_is_need,
      'consent_model', 'free_interest'
    ),
    false
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_listing_interest ON public.likes;
CREATE TRIGGER trg_notify_listing_interest
AFTER INSERT OR UPDATE OF direction ON public.likes
FOR EACH ROW
EXECUTE FUNCTION public.notify_listing_interest();

REVOKE ALL ON FUNCTION public.notify_listing_interest() FROM PUBLIC, anon, authenticated;
