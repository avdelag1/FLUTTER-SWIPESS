-- Restrict legal dashboard mutations to narrow, audited RPCs.

create or replace function public.transition_legal_video_call(
  p_call_id uuid,
  p_status text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_is_active_lawyer boolean := false;
  v_client_id uuid;
  v_lawyer_id uuid;
  v_current_status text;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select client_user_id, lawyer_user_id, status
    into v_client_id, v_lawyer_id, v_current_status
  from public.legal_video_calls
  where id = p_call_id
  for update;

  if not found then return false; end if;

  v_is_admin := public.is_admin_user(v_uid);
  select exists(
    select 1 from public.lawyer_users
    where user_id = v_uid and is_active = true
  ) into v_is_active_lawyer;

  if p_status = 'accepted' then
    if not v_is_active_lawyer or v_current_status <> 'ringing' then return false; end if;
    update public.legal_video_calls
       set lawyer_user_id = v_uid,
           status = 'accepted',
           answered_at = now()
     where id = p_call_id and status = 'ringing';
    return found;
  end if;

  if v_uid = v_client_id then
    if p_status not in ('missed','cancelled','ended') then return false; end if;
    if p_status in ('missed','cancelled') and v_current_status <> 'ringing' then return false; end if;
    update public.legal_video_calls
       set status = p_status,
           ended_at = now()
     where id = p_call_id;
    return found;
  end if;

  if v_uid = v_lawyer_id or v_is_admin then
    if p_status not in ('ended','cancelled') then return false; end if;
    update public.legal_video_calls
       set status = p_status,
           ended_at = now()
     where id = p_call_id;
    return found;
  end if;

  return false;
end;
$$;

revoke all on function public.transition_legal_video_call(uuid, text) from public, anon;
grant execute on function public.transition_legal_video_call(uuid, text) to authenticated;

create or replace function public.update_legal_request_workflow(
  p_request_id uuid,
  p_status text,
  p_lawyer_notes text default null
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_allowed boolean := false;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_status not in ('pending','reviewing','in_progress','completed','closed','cancelled') then
    raise exception 'invalid legal request status' using errcode = '22023';
  end if;

  v_allowed := public.is_admin_user(v_uid) or exists(
    select 1 from public.lawyer_users
    where user_id = v_uid and is_active = true
  );
  if not v_allowed then
    raise exception 'insufficient privilege' using errcode = '42501';
  end if;

  update public.legal_package_requests
     set status = p_status,
         lawyer_notes = case
           when p_lawyer_notes is null then lawyer_notes
           else left(trim(p_lawyer_notes), 5000)
         end,
         updated_at = now()
   where id = p_request_id;
  return found;
end;
$$;

revoke all on function public.update_legal_request_workflow(uuid, text, text) from public, anon;
grant execute on function public.update_legal_request_workflow(uuid, text, text) to authenticated;

revoke update on table public.legal_video_calls from authenticated;
revoke update on table public.legal_package_requests from authenticated;
grant select, insert on table public.legal_video_calls to authenticated;
grant select, insert on table public.legal_package_requests to authenticated;