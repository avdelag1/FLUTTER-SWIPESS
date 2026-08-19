-- Global complimentary Premium reset for the 1.2.36 (621) release.
--
-- Existing accounts receive three calendar months beginning at this reset
-- timestamp. Accounts created after this timestamp receive three calendar
-- months from their own signup time. The client subscription repository uses
-- signup_starts_at as the reset anchor and keeps any paid subscription under
-- the complimentary Premium entitlement so paid access resumes afterward.

update public.app_access_campaigns
set
  signup_starts_at = timestamptz '2026-08-19 03:26:00.222139+00',
  signup_ends_at = null,
  trial_months = 3,
  accepting_new_signups = true,
  updated_at = timestamptz '2026-08-19 03:26:00.222139+00'
where campaign_key = 'new_user_premium_trial';
