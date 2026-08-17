-- Allow a signed-in participant to unsend only messages they authored.
-- The same policy has been applied to the production Supabase project.
create policy messages_delete_own
on public.conversation_messages
for delete
to authenticated
using (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.conversations c
    where c.id = conversation_messages.conversation_id
      and (c.client_id = auth.uid() or c.owner_id = auth.uid())
  )
);
