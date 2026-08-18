UPDATE public.likes
SET dismiss_count = 1,
    dismissed_at = COALESCE(dismissed_at, created_at, now()),
    cooldown_until = COALESCE(dismissed_at, created_at, now()) + interval '7 days'
WHERE direction = 'left' AND COALESCE(dismiss_count, 0) < 1;

UPDATE public.likes
SET dismiss_count = 0,
    dismissed_at = NULL,
    cooldown_until = NULL
WHERE direction = 'right' AND COALESCE(dismiss_count, 0) <> 0;
