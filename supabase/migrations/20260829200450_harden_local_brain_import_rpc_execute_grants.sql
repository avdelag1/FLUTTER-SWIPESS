revoke all on function public.rpc_import_local_brain_entries(jsonb) from public;
revoke execute on function public.rpc_import_local_brain_entries(jsonb) from anon;
grant execute on function public.rpc_import_local_brain_entries(jsonb) to authenticated;

revoke all on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) from public;
revoke execute on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) from anon;
grant execute on function public.rpc_search_local_brain(text,text,double precision,double precision,integer) to authenticated;
