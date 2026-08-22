-- Consumer Legal actions require paid Premium or the active welcome period.
-- Lawyer/admin workflows remain governed by their existing role policies.

create or replace function public.rpc_submit_legal_intake(
  p_package_id uuid,
  p_package_name text,
  p_package_category text,
  p_quoted_price numeric,
  p_situation text,
  p_city text,
  p_full_name text,
  p_email text,
  p_phone text,
  p_preferred_contact text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not public.rpc_has_premium_feature_access() then
    raise exception 'Premium membership required for Legal services';
  end if;
  if length(trim(coalesce(p_situation, ''))) < 12 then
    raise exception 'Please describe your situation in a bit more detail';
  end if;
  if length(trim(coalesce(p_package_category, ''))) < 2 then
    raise exception 'Choose a legal category';
  end if;

  insert into public.legal_package_requests (
    requested_by, package_id, package_name, package_category, quoted_price,
    situation, city, full_name, email, phone, preferred_contact,
    request_type, status, source, expires_at
  ) values (
    v_uid, p_package_id, nullif(trim(p_package_name), ''),
    trim(p_package_category), p_quoted_price,
    trim(p_situation), nullif(trim(p_city), ''),
    nullif(trim(p_full_name), ''), nullif(trim(p_email), ''),
    nullif(trim(p_phone), ''), coalesce(nullif(trim(p_preferred_contact), ''), 'phone'),
    'intake', 'pending', 'swipess_app', now() + interval '48 hours'
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.rpc_submit_legal_intake(uuid,text,text,numeric,text,text,text,text,text,text) from public, anon;
grant execute on function public.rpc_submit_legal_intake(uuid,text,text,numeric,text,text,text,text,text,text) to authenticated;

drop policy if exists "Users can insert own package requests" on public.legal_package_requests;
create policy "Users can insert own package requests"
on public.legal_package_requests
for insert
to authenticated
with check (
  auth.uid() = requested_by
  and public.rpc_has_premium_feature_access()
);

drop policy if exists "lvc_client_insert" on public.legal_video_calls;
create policy "lvc_client_insert"
on public.legal_video_calls
for insert
to authenticated
with check (
  client_user_id = auth.uid()
  and public.rpc_has_premium_feature_access()
);

drop policy if exists "Users can submit legal requests" on public.legal_help_requests;
create policy "Users can submit legal requests"
on public.legal_help_requests
for insert
to authenticated
with check (
  auth.uid() = user_id
  and public.rpc_has_premium_feature_access()
);
