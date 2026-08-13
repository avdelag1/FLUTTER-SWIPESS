-- Event host socials. WhatsApp stays on organizer_whatsapp (phone → wa.me).
alter table public.events
  add column if not exists organizer_instagram text,
  add column if not exists organizer_website text,
  add column if not exists organizer_facebook text;
